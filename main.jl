using PrettyTables
using HTTP
using JSON
using CSV
using DataFrames
using LinearAlgebra
using Statistics
using Plots

# Carrega os dados
df = CSV.read("bosses_dados.csv", DataFrame; delim=',')

# renomeia algumas colunas
rename!(df, "Loud (Db)" => :Loudness, "BPM" => :Tempo)

# Limpa os dados
select!(df, :Song, :Dance, :Energy, :Acoustic, :Instrumental, :Happy, :Loudness, :Tempo, :Speech, :Live)
pretty_table(df)
boss_names = df.Song
select!(df, Not(:Song))

# Pre processamento
features = Matrix{Float64}(df)'


function normalizaDados(M)
    M_norm = copy(M)
    l, c = size(M)

    for i in 1:l
        media = mean(M[i, :])
        desvio = std(M[i, :])

        if desvio != 0
            M_norm[i, :] = (M[i, :] .- media) ./ desvio
        end
    end

    return M_norm
end

data_matrix = normalizaDados(features)

function metodoPot(C)
    n, m = size(C)
    v = randn(n, 1)

    for i=1:100
        v = C*v
        v = v/norm(v)
    end

    return v, only(v'*C*v)
end

function fazPCA(k, A)
    # k = numero de componentes
    # A = matriz de dados

    vetores_principais = [] # os eixos
    scores = []             # a projecao nos eixos

    A_temp = copy(A)

    for i in 1:k
        # Matriz de Covariancia
        C = A_temp * A_temp'

        # Acha o maior autovalor e autovetor da matriz
        v, lambda = metodoPot(C)

        # Projeta os dados nesse autovetor
        pc_scores = v' * A_temp

        push!(vetores_principais, v)
        push!(scores, pc_scores)

        A_temp = A_temp - (v * (v' *A_temp))
    end

    return vetores_principais, scores
end

function fazPcaComErro(max_k, A)
    println("[*] Calculando erro...")
    erros = Float64[]

    norma_total = norm(A)

    A_temp = copy(A)

    for i in 1:max_k
        C = A_temp * A_temp'
        v, lambda = metodoPot(C)

        A_temp = A_temp - (v * (v' * A_temp))

        erro_atual = norm(A_temp)

        erro_relativo = erro_atual / norma_total
        push!(erros, erro_relativo)
    end

    return erros
end

num_features = size(data_matrix, 1)

historico_erros = fazPcaComErro(num_features, data_matrix)

erro_img = "teste_erros.png"
println("[*] Salvando erros em $erro_img")

p = plot(1:num_features, historico_erros,
     title = "Erro de reconstrucao",
     xlabel = "Numero de componentes (k)",
     ylabel = "Erro relativo",
     label = "Erro",
     marker = :circle,
     linewidth = 2,
     color = :blue,
     legend = :topright
)

savefig(p, erro_img)

println("[*] Erros salvos em $erro_img")

# ======================================
#           GERANDO MAPA 3D
# ======================================

println("\nGerando mapa 3D dos dados")

vetores_3d, scores_3d = fazPCA(3, data_matrix)

xs = vec(scores_3d[1])
ys = vec(scores_3d[2])
zs = vec(scores_3d[3])

# --- LOGICA PARA ACHAR OS CHEFES FAMOSOS ---
destaques = ["Gwyn", "Nameless", "Vordt", "Ornstein", "Gael", "Soul of Cinder", "Artorias", "Friede", "Malenia", "Ludwig"]
ids_anotar = Int[]

for (i, nome) in enumerate(boss_names)
    # Verifica se parte do nome está na lista de destaques
    if any(occursin(d, nome) for d in destaques)
        push!(ids_anotar, i)
    end
end
# -------------------------------------------

println("[*] Gerando frames da animação...")

anim = @animate for i in 0:2:360
    # Plota a nuvem geral
    p = scatter3d(xs, ys, zs,
        title = "Universo Souls (Rotacionando)",
        xlabel = "PC1 - Complexidade da Composição", ylabel = "PC2 - Atmosfera", zlabel = "PC3 - Caos/Adrenalina",
        legend = false, color = :darkred, markersize = 4, alpha = 0.6,
        size = (900, 700), camera = (i, 30)
    )
    
    # Adiciona os textos APENAS nos destaques (para não poluir)
    # Em 3D, usamos annotations dentro do plot!
    plot!(p, annotations = [
        (xs[j], ys[j], zs[j], text(boss_names[j], 8, :black, :bottom)) 
        for j in ids_anotar
    ])
end

nome_gif = "animacao_souls.gif"
#gif(anim, nome_gif, fps = 15)
println("[*] Mapa 3D salvo em $nome_gif")

println("[*] Comecando plot em 3D dos dados")
p = scatter3d(xs, ys, zs,
    title = "Universo Souls",
    xlabel = "PC1 (Complexidade)",
    ylabel = "PC2 (Atmosfera)",
    zlabel = "PC3 (Energia)",
    legend = false,
    color = :darkred,
    markersize = 5,
    alpha = 0.8,
    size = (900, 700),
    camera = (45, 30)# <--- AQUI A MÁGICA ACONTECE
)

# Plota os textos
plot!(p, annotations = [
    (xs[j], ys[j], zs[j], text(boss_names[j], 8, :black, :bottom)) 
    for j in ids_anotar
])

nome_plot3d = "plot3d_souls.png"
savefig(p, nome_plot3d)
println("[*] Plot salvo em $nome_plot3d")


function recomendaChefe(inputUser::Vector{Float64}, matrizCompleta, nomes)
    ranking = []

    num_chefes = size(matrizCompleta, 2)

    for i in 1:num_chefes
        features_chefe = matrizCompleta[:, i]

        dist = norm(inputUser - features_chefe)

        push!(ranking, (nomes[i], dist))
    end

    sort!(ranking, by = x -> x[2])

    return ranking
end

function coletaDados()
    println("[*] Coletando dados do usuario...")
    println("Responda de 1.0 (minimo) a 5.0 (maximo)")

    function perguntar(txt)
        print("$txt [1.0 - 5.0]: ")
        input = readline()

        input = replace(input, "," => ".")

        valor = tryparse(Float64, input)
        if isnothing(valor) || valor < 1.0 || valor > 5.0
            println("Valor invalido, assumindo neutro (3.0)")
            return 0.0
        end

        return (valor - 3.0)
    end

    p_intensa = perguntar("1. Quão intensa/barulhenta deve ser a música?")
    p_rapida = perguntar("2. Quão rápida deve ser a música?")
    p_feliz = perguntar("3. A música deve ser triste (1) ou heróica/vitoriosa (5)?")
    p_acustica = perguntar("4. Prefere orquestra pesada (1) ou instrumento solo/acústico (5)?")
    p_vozes = perguntar("5. Prefere apenas instrumentos (1) ou coral/vozes (5)?")
    p_ritmo = perguntar("6. A musica deve ser caotica/quebrada (1) ou constante/dancante (5)?")

    vetor_final = zeros(9)

    vetor_final[1] = p_ritmo * 0.8
    vetor_final[2] = p_intensa
    vetor_final[3] = p_acustica
    vetor_final[4] = -1.0 * p_vozes
    vetor_final[5] = p_feliz
    vetor_final[6] = p_intensa
    vetor_final[7] = p_rapida
    if p_vozes > 1.0
        vetor_final[8] = 0.5
    else
        vetor_final[8] = -1.0
    end
    vetor_final[9] = 0.0

    return vetor_final
end

perfil_user = coletaDados()
recs = recomendaChefe(perfil_user, data_matrix, boss_names)

println("Você deveria ouvir: $(recs[1][1])")
