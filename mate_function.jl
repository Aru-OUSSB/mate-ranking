function ID2df(i,user_name,user_image_url,rate_now,rate_max,rate_log,wins,losses)
    url = "https://smashmate.net/user/$(ID[i])/"

    # HTTPリクエストでHTMLを取得
    response::HTTP.Messages.Response = HTTP.get(url)

    # HTMLのパース
    responsebody::Vector{UInt8}=response.body
    # print(typeof(responsebody))
    html_content::String = String(responsebody)
    parsed_html::HTMLDocument = parsehtml(html_content)

    # ユーザー名の抽出
    nodes1::Vector{HTMLNode} = eachmatch(Selector("span.user-name"), parsed_html.root)
    user_name[i] = nodes1[1][1].text
    # ユーザー画像URLの抽出
    nodes2::Vector{HTMLNode} = eachmatch(Selector("img.user-image"), parsed_html.root)
    user_image_url[i] = nodes2[1].attributes["src"]

    # 現在レートを抽出
    rate_selector = Selector("div.col-xs-6")
    rate = eachmatch(rate_selector, parsed_html.root)
    if length(rate)>2
        rate_now[i] = parse(Int,strip(rate[2][1][1].text))
        rate_max[i] = parse(Int,strip(rate[4][1][1].text))
        rate_log[i] = strip(rate[6][1].text)
        wins[i],losses[i] = extract_win_loss(rate_log[i])
    else
        rate_now[i] = 1000
        rate_max[i] = 1000
        rate_log[i] = "0勝 0敗"
        wins[i] = 0
        losses[i] = 0
    end
end
