using HTTP
using Dates
# エラーログを有効化
ENV["JULIA_DEBUG"] = "all"

include("mate.jl")

# HTMLテンプレート
const HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Mate Rate Ranking</title>
    <meta charset="UTF-8">
    <style>
        body {
            margin: 0;
            padding: 20px;
            background-color: #f0f0f0;
            font-family: Arial, sans-serif;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }
        .header {
            margin-bottom: 20px;
            text-align: center;
        }
        .title {
            margin: 0;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: center;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        .player-info {
            display: flex;
            align-items: center;
            gap: 10px;
            justify-content: flex-start;
        }
        .player-photo {
            width: 40px;
            height: 40px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="title">レートランキング</h1>
        </div>
        {{RANKING_TABLE}}
    </div>
</body>
</html>
"""

# キャッシュ用のグローバル変数
mutable struct Cache
    data::Union{Nothing, NamedTuple}
    last_update::Float64
end

const CACHE = Cache(nothing, 0.0)
const CACHE_DURATION = 10 * 60  # 10分（秒単位）

# バックグラウンドでキャッシュを更新する関数
function update_cache_periodically()
    while true
        try
            @info "Scheduled cache update starting..."
            CACHE.data = get_current_ranking()
            CACHE.last_update = time()
            @info "Cache updated successfully"
            sleep(CACHE_DURATION)  # 10分待機
        catch e
            @error "Error in periodic cache update" exception=(e, catch_backtrace())
            sleep(60)  # エラー時は1分待って再試行
        end
    end
end

# サーバー起動時にバックグラウンドタスクを開始
function start_background_tasks()
    @async update_cache_periodically()
end

# キャッシュされたデータを取得する関数
function get_cached_ranking()
    if isnothing(CACHE.data)
        try
            @info "Initial cache population..."
            CACHE.data = get_current_ranking()
            CACHE.last_update = time()
            @info "Initial cache populated successfully"
        catch e
            @error "Error in initial cache population" exception=(e, catch_backtrace())
            rethrow(e)
        end
    end
    return CACHE.data
end

# ランキングテーブルを生成する関数
function generate_ranking_table()
    try
        df = get_cached_ranking()  # キャッシュされたデータを使用
        
        rows = String[]
        push!(rows, """
            <tr>
                <th>順位</th>
                <th>プレイヤー</th>
                <th>現在レート</th>
                <th>最高レート</th>
                <th>対戦成績</th>
            </tr>
        """)
        
        for i in 1:N
            row = (img_url=df.url[i], name=df.Name[i], current_rate=df.Now[i], max_rate=df.Max[i], Log = df.Log[i])
            
            player_html = """
                <tr>
                    <td>$(i)</td>
                    <td>
                        <div class="player-info">
                            <img src="$(row.img_url)" class="player-photo" alt="$(row.name)">
                            $(row.name)
                        </div>
                    </td>
                    <td>
                        $(round(Int, row.current_rate))
                    </td>
                    <td>
                        $(round(Int, row.max_rate))
                    </td>
                    <td>$(row.Log)</td>
                </tr>
            """
            push!(rows, player_html)
        end
        
        # 最終更新時刻を追加
        # last_update = Dates.format(Dates.unix2datetime(CACHE.last_update), "yyyy-mm-dd HH:MM:SS")
        # update_info = """
        #     <div style="text-align: right; margin-top: 10px; color: #666;">
        #         最終更新: $(last_update)
        #     </div>
        # """
        
        return "<table>" * join(rows) * "</table>"# * update_info
    catch e
        @error "Error generating ranking table" exception=(e, catch_backtrace())
        return "<p>ランキングの読み込み中にエラーが発生しました。</p>"
    end
end

# メインページのハンドラー
function main_handler(req::HTTP.Request)
    try
        if req.method == "HEAD"
            return HTTP.Response(200, ["Content-Type" => "text/html"])
        end

        ranking_table = generate_ranking_table()
        html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>スマメイトレート ランキング</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    margin: 20px;
                    background-color: #f5f5f5;
                }
                table {
                    width: 100%;
                    border-collapse: collapse;
                    background-color: white;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.2);
                }
                th, td {
                    padding: 12px;
                    text-align: left;
                    border-bottom: 1px solid #ddd;
                }
                th {
                    background-color: #4CAF50;
                    color: white;
                }
                tr:nth-child(even) {
                    background-color: #f9f9f9;
                }
                tr:hover {
                    background-color: #f5f5f5;
                }
                img {
                    width: 50px;
                    height: 50px;
                    border-radius: 25px;
                }
                .update-info {
                    text-align: right;
                    color: #666;
                    margin-top: 10px;
                    font-size: 0.9em;
                }
            </style>
        </head>
        <body>
            <h1>スマメイトレート ランキング</h1>
            $(ranking_table)
            <div class="update-info">
                10分ごとに自動更新
            </div>
        </body>
        </html>
        """
        
        return HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"], body=html)
    catch e
        @error "Error in main_handler" exception=(e, catch_backtrace())
        return HTTP.Response(500, "Internal Server Error")
    end
end

# ルーターの設定
const ROUTER = HTTP.Router()
HTTP.register!(ROUTER, "GET", "/", main_handler)
HTTP.register!(ROUTER, "HEAD", "/", main_handler)

# サーバーの起動
function start_server(port=8080)
    # Render環境ではPORT環境変数を使用
    port = parse(Int, get(ENV, "PORT", string(port)))
    
    is_production = haskey(ENV, "RENDER")
    host = is_production ? "0.0.0.0" : "127.0.0.1"
    
    start_background_tasks()  # バックグラウンドタスクを開始
    
    if is_production
        println("Starting production server on port $port")
    else
        println("Starting development server on http://localhost:$port")
    end
    
    HTTP.serve(ROUTER, host, port)
end

# エラーハンドリングを追加
# if abspath(PROGRAM_FILE) == @__FILE__
    try
        start_server()
    catch e
        @error "Server error" exception=(e, catch_backtrace())
        rethrow(e)
    end
# end
