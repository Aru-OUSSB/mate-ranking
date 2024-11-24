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
const CACHE_DURATION = 15 * 60  # 15分（秒単位）

# キャッシュされたデータを取得する関数
function get_cached_ranking()
    current_time = time()
    
    # キャッシュが空か期限切れの場合、新しいデータを取得
    if isnothing(CACHE.data) || (current_time - CACHE.last_update) > CACHE_DURATION
        try
            @info "Updating cache..."
            CACHE.data = get_current_ranking()
            CACHE.last_update = current_time
            @info "Cache updated successfully"
        catch e
            @error "Error updating cache" exception=(e, catch_backtrace())
            # キャッシュの更新に失敗した場合、古いデータを使用
            if isnothing(CACHE.data)
                rethrow(e)  # 初回の場合はエラーを投げる
            end
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
        html = replace(HTML_TEMPLATE, "{{RANKING_TABLE}}" => ranking_table)
        
        return HTTP.Response(200, ["Content-Type" => "text/html"], html)
    catch e
        @error "Error in main_handler" exception=(e, catch_backtrace())
        return HTTP.Response(500, ["Content-Type" => "text/html"], 
            body="<html><body><h1>Internal Server Error</h1><p>申し訳ありませんが、エラーが発生しました。</p></body></html>")
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
