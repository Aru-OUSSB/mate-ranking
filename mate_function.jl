function extract_text_between(content::AbstractString, start_marker::AbstractString, end_marker::AbstractString)
    s = findfirst(start_marker, content)
    if isnothing(s)
        return nothing
    end
    start_pos = last(s) + 1
    e = findnext(end_marker, content, start_pos)
    if isnothing(e)
        return nothing
    end
    x = first(e)
    while true
        x-=1
        try
            moji = content[x]
            break
        catch
        end
    end
    return strip(content[start_pos:x])
end

function safe_extract_image_url(content::AbstractString, start_pos::Integer)
    try
        src_start = findnext("src=\"", content, start_pos)
        isnothing(src_start) && return nothing
        
        src_end = findnext("\"", content, last(src_start) + 1)
        isnothing(src_end) && return nothing
        
        url = content[last(src_start)+1:first(src_end)-1]
        return isempty(url) ? nothing : url
    catch
        return nothing
    end
end

function safe_parse_rate(rate_str::Union{AbstractString, Nothing})
    try
        isnothing(rate_str) && return 1000
        cleaned = strip(replace(rate_str, r"[^0-9]" => ""))
        isempty(cleaned) && return 1000
        return parse(Int, cleaned)
    catch
        return 1000
    end
end

# ランダムなUser-Agentを生成する関数
function random_user_agent()
    user_agents = [
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0",
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Edge/119.0.0.0",
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
    ]
    return rand(user_agents)
end

function ID2df(i,user_name,user_image_url,rate_now,rate_max,rate_log)
    url = "https://smashmate.net/user/$(ID[i])/"
    max_retries = 3
    retry_delay = rand(5:10)  # 5-10秒のランダムな待機時間

    for retry_count in 1:max_retries
        try
            # より自然なブラウザヘッダー
            headers = [
                "User-Agent" => random_user_agent(),
                "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
                "Accept-Language" => "ja,en-US;q=0.9,en;q=0.8",
                "Accept-Encoding" => "gzip, deflate, br",
                "Connection" => "close",
                "Cache-Control" => "max-age=0",
                "Sec-Ch-Ua" => "\"Google Chrome\";v=\"119\", \"Chromium\";v=\"119\", \"Not?A_Brand\";v=\"24\"",
                "Sec-Ch-Ua-Mobile" => "?0",
                "Sec-Ch-Ua-Platform" => "\"Windows\"",
                "Sec-Fetch-Dest" => "document",
                "Sec-Fetch-Mode" => "navigate",
                "Sec-Fetch-Site" => "none",
                "Sec-Fetch-User" => "?1",
                "Upgrade-Insecure-Requests" => "1",
                "Pragma" => "no-cache"
            ]
            
            # リクエスト前に少し待機
            sleep(rand(2:4))
            
            response = HTTP.get(url, headers; 
                redirect=true,
                retry=false,
                readtimeout=30,
                connect_timeout=30,
                status_exception=false
            )

            # レスポンスステータスのチェック
            if response.status != 200
                error("HTTP status $(response.status)")
            end

            # 応答が空でないことを確認
            if isempty(response.body)
                error("Empty response body")
            end

            content = String(response.body)
        
            # 文字列に変換して必要な情報のみを抽出
            # ユーザー名を抽出
            name_content = extract_text_between(content, "<span class=\"user-name\">", "</span>")
            user_name[i] = isnothing(name_content) ? "Unknown" : name_content

            # ユーザー画像URLを抽出
            img_start_0 = findall("<div class=\"col-xs-4\">",content)[2][end]
            img_start_1 = findfirst("src=\"",content[img_start_0:end])[end]
            img_start = img_start_0 + img_start_1
            img_pos_0 = findfirst('"',content[img_start:end])
            img_pos = img_start + img_pos_0 - 2
            user_image_url[i] = content[img_start:img_pos]

            # レート情報を抽出
            rate_divs = findall("<div class=\"col-xs-6\">", content)
            if length(rate_divs) > 5
                # 現在のレート
                current_rate_z = findfirst("</span>",content[rate_divs[2][end]:rate_divs[3][1]])[1]
                rate_now[i] = parse(Int,match(r"\d{4}",content[rate_divs[2][end]:rate_divs[2][end]+current_rate_z]).match)
                
                # 最大レート
                max_rate_z = findfirst("</span>",content[rate_divs[4][end]:rate_divs[5][1]])[1]
                rate_max[i] = parse(Int,match(r"\d{4}",content[rate_divs[4][end]:rate_divs[4][end]+max_rate_z]).match)
                
                # 対戦成績
                battle_log = extract_text_between(content[rate_divs[6][end]:rate_divs[7][1]], ">", "</div>")
                battle_log_z = findfirst("敗",battle_log)[1]
                rate_log[i] = isnothing(battle_log) ? "0勝 0敗" : battle_log[1:battle_log_z]
            else
                rate_now[i] = rate_max[i] = 1000
                rate_log[i] = "0勝 0敗"
            end

            break  # リトライ不要
        catch e
            if retry_count < max_retries
                @warn "Error fetching data for ID $(ID[i]): $e. Retrying in $retry_delay seconds..."
                sleep(retry_delay)
            else
                @warn "Error fetching data for ID $(ID[i]): $e"
                rate_now[i] = rate_max[i] = 1000
                rate_log[i] = "0勝 0敗"
                user_name[i] = "Error"
                user_image_url[i] = ""
            end
        end
    end
    
    # メモリを明示的に解放
    GC.gc()
end
