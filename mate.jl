using HTTP
# HTMLのサンプルを読み込む（ファイルまたは文字列として）
include("./mate_ID.jl")
include("./mate_function.jl")

const N = length(ID)

function main()
    try
        user_name = Vector{String}(undef,N)
        user_image_url = Vector{String}(undef,N)
        rate_now = Vector{Int}(undef,N)
        rate_max = Vector{Int}(undef,N)
        rate_log = Vector{String}(undef,N)

        for i in 1:N
            try
                ID2df(i,user_name,user_image_url,rate_now,rate_max,rate_log)
            catch e
                @error "Error fetching data for ID $(ID[i])" exception=(e, catch_backtrace())
                user_name[i] = "Unknown"
                user_image_url[i] = ""
                rate_now[i] = 1000
                rate_max[i] = 1000
                rate_log[i] = "0勝 0敗"
            end
        end

        junban = [rate_now[i]*10000 + rate_max[i] + 1/ID[i] for i in 1:N]

        rank = sortperm(junban, rev=true)

        df = (ID=ID[rank], Name = user_name[rank], url = user_image_url[rank], Now = rate_now[rank], Max = rate_max[rank], Log = rate_log[rank])

        
        
        # df = DataFrame(ID = ID, Name = user_name, url = user_image_url, Now = rate_now, Max = rate_max, Log = rate_log)    
        
        
        # # mate_data.csvが存在しない場合は新規作成
        # if !isfile("./mate_data.csv")
        #     CSV.write("./mate_data.csv", df0)
        #     return df0
        # end

        # # 既存のデータと結合
        # df1 = DataFrame(CSV.File("./mate_data.csv"))
        # df = outerjoin(df0, df1, on=[:ID], makeunique=true)
        # df.dNow = coalesce.(df.Now - df.Now_1, 0)
        # df.dMax = coalesce.(df.Max - df.Max_1, 0)

        # df.ID = df.ID*-1
        # df = sort!(df, [:Now, :Max, :ID], rev = true)
        # df.ID = df.ID*-1

        return df
    catch e
        @error "Error in main function" exception=(e, catch_backtrace())
        # エラー時はダミーデータを返す
        return DataFrame(
            ID = ID,
            Name = fill("Error", N),
            url = fill("", N),
            Now = fill(1000, N),
            Max = fill(1000, N),
            Log = fill("0勝 0敗", N),
            # dNow = fill(0, N),
            # dMax = fill(0, N)
        )
    end
end

# function main_once_a_day()
#     user_name = Vector{String}(undef,N)
#     user_image_url = Vector{String}(undef,N)
#     rate_now = Vector{Int}(undef,N)
#     rate_max = Vector{Int}(undef,N)
#     rate_log = Vector{String}(undef,N)

#     for i in 1:N
#         ID2df(i,user_name,user_image_url,rate_now,rate_max,rate_log)
#     end

#     df0 = DataFrame(ID = ID, Name = user_name, Now = rate_now, Max = rate_max)
#     CSV.write("./mate_data.csv",df0)
# end

function get_current_ranking()
    
    df = main()
    
    return df
end
