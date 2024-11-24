using HTTP, Dates
include("mate.jl")

function generate_ranking_table(ranking_data)
    try
        rows = String[]
        
        # ヘッダー行
        push!(rows, """
            <tr>
                <th>順位</th>
                <th>プレイヤー</th>
                <th>現在のレート</th>
                <th>最高レート</th>
                <th>対戦成績</th>
            </tr>
        """)
        
        # データ行
        for i in 1:length(ranking_data.user_name)
            player_html = """
                <tr>
                    <td>$(i)</td>
                    <td>
                        <div class="player-info">
                            <img src="$(ranking_data.user_image_url[i])" class="player-photo">
                            <span>$(ranking_data.user_name[i])</span>
                        </div>
                    </td>
                    <td>$(ranking_data.rate_now[i])</td>
                    <td>$(ranking_data.rate_max[i])</td>
                    <td>$(ranking_data.rate_log[i])</td>
                </tr>
            """
            push!(rows, player_html)
        end
        
        return "<table>" * join(rows) * "</table>"
    catch e
        @error "Error generating ranking table" exception=(e, catch_backtrace())
        return "<p>ランキングの読み込み中にエラーが発生しました。</p>"
    end
end

function generate_static_html()
    try
        ranking_data = get_current_ranking()
        ranking_table = generate_ranking_table(ranking_data)
        last_update = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
        
        html = """
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
                .update-info {
                    text-align: right;
                    color: #666;
                    margin-top: 10px;
                    font-size: 0.9em;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1 class="title">レートランキング</h1>
                </div>
                $(ranking_table)
                <div class="update-info">
                    最終更新: $(last_update)
                </div>
            </div>
        </body>
        </html>
        """
        
        # docsディレクトリにHTMLを保存
        mkpath("docs")
        write("docs/index.html", html)
        @info "Ranking HTML generated successfully"
    catch e
        @error "Error generating static HTML" exception=(e, catch_backtrace())
        rethrow(e)
    end
end

generate_static_html()
