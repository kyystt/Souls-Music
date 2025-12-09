using HTTP
using JSON
using CSV
using DataFrames
using DotEnv

DotEnv.load!()

df = CSV.read("bosses_dados.csv", DataFrame; delim=',')

select!(df, :Song, :Dance, :Energy, :Acoustic, :Instrumental, :Happy)

spotify_token = ENV["SPOTIFY_TOKEN"]

function fetch_api_data(url::String, token::String="")
    println("Fazendo a requisição para $url")

    headers = ["Authorization" => "Bearer $token"]
    try
        response = HTTP.get(url, headers)

        if response.status == 200
            data = JSON.parse(String(response.body))
            return data
        else
            println("erro fetch()")
            return nothing
        end
    catch e
        println("erro: $e")
        return nothing
    end
end

println(df)
