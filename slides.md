# Slides da Apresentação — Projeto IA 2026.1
# *Using machine learning to predict child active transportation prevalence*

---

---

## BLOCO 2 — BASE DE DADOS (5 min)

---

### Slide 5 — Estudo CHASE 2018

**Título do slide:** O que é o CHASE 2018?

**Conteúdo principal:**

- **C**hild **H**ealth **A**ctive Trans**S**portation **E**study — levantamento nacional canadense
- **552 escolas** em **7 cidades**: Calgary, Peel Region, Toronto, Montreal, Laval, Surrey, Vancouver
- Dados coletados entre 2012 e 2018 via contagem de modos de transporte na chegada à escola
- Fonte pública: repositório **Borealis** — DOI: `10.5683/SP3/W9YL4Q`

**Elemento visual sugerido:**
> Mapa do Canadá com os 7 pontos marcados (Calgary=AB, Montreal/Laval=QC, Peel/Toronto=ON, Surrey/Vancouver=BC)

**Nota de rodapé:**
> Cada unidade de análise é uma *escola*, não um aluno — o modelo prevê a proporção de TA da escola, não de um indivíduo.

---

### Slide 6 — Os Dois Arquivos de Dados

**Título do slide:** Dois arquivos, uma junção

**Tabela central:**

| Arquivo | O que contém | Linhas |
|---|---|---|
| `CAN_Surveyed_Schools.tab` | Modos de transporte, walkscore, matrícula | 555 (3 inválidas removidas) |
| `CAN_Schools_Catchment.tab` | Área, população, infraestrutura viária, uso do solo, ciclofaixas | 552 |

**Junção:**
```
LEFT JOIN por Schoolid
→ dataset final: 552 linhas × 205 colunas
```

**Detalhe técnico para falar:**
- "Schools" traz o que foi *observado* em campo (crianças caminhando, walkscore do endereço)
- "Catchment" traz o contexto *geográfico e urbano* da zona de captação da escola (área, tipo de solo, infraestrutura)
- O LEFT JOIN preserva todas as 552 escolas válidas; nenhuma escola fica de fora por falta de dado de catchment

**Dado curioso:**
> 3 linhas com Schoolid vazio foram removidas — escolas sem identificador não têm dados válidos

---

### Slide 7 — Variável-Alvo

**Título do slide:** O que estamos prevendo?

**Definição em destaque:**
> **`active_t_prop`** — proporção de crianças que vão à escola caminhando ou de bicicleta
> Valor contínuo entre **0** (nenhuma criança usa TA) e **1** (todas as crianças usam TA)

**Tabela de estatísticas descritivas:**

| Estatística | Valor |
|---|---|
| Mínimo | 0,00 |
| 1º Quartil | 0,41 |
| **Mediana** | **0,54** |
| **Média** | **0,54** |
| 3º Quartil | 0,68 |
| Máximo | 1,00 |

**Elemento visual:** Histograma gerado no projeto
> Forma aproximadamente normal centrada em 0,54 — metade das escolas tem entre 41% e 68% das crianças usando TA

**Para falar:**
- Problema de **regressão** (não classificação): a árvore prevê um número real, não uma categoria
- Distribuição simétrica justifica o uso de RMSE como métrica (sem valores extremos dominando)
- Escola com `active_t_prop = 0,80` → 80% das crianças caminham ou vão de bicicleta

---

### Slide 8 — Preditores Utilizados

**Título do slide:** 127 preditores organizados em categorias

**Categorias e exemplos:**

| Categoria | Exemplos de variáveis |
|---|---|
| Densidade populacional | `pop_den`, `child_den`, `multihome_den`, `immigrant_den` |
| Infraestrutura viária | `road_den`, `density_major_roads`, `density_intersections` |
| Infraestrutura ciclística | `density_bicycle_class`, `density_curb_extensions` |
| Uso do solo | `proportion_commercial_area`, `proportion_industrial_area`, `open_area` |
| Ambiente urbano | `walkscore`, `density_pre_1960_houses`, `ActLivClassEnv` |
| Escola | `enrollment`, `school_num` |
| Variável geográfica | `city` (fator com 7 níveis) |

**Destaque:**
> **127 preditores** após remoção de variáveis redundantes, identificadores e colineares

**Dado ausente — por quê está faltando:**
> `collisions_child` e `collisions_adult` = **NA em todas as 552 escolas**
> Confirmado pela documentação CHASE: dados de colisão são registros municipais restritos, não disponíveis no repositório público

---

---

## BLOCO 3 — METODOLOGIA E ALGORITMO (10 min)

---

### Slide 9 — Pipeline do Projeto

**Título do slide:** Do dado bruto à previsão

**Diagrama em etapas (texto para montar visualmente):**

```
[Dados brutos]          [Feature Engineering]       [Divisão]
.tab Schoolid     →     merge + aliases          →   80% treino
.tab Catchment          variáveis derivadas           20% teste
                        (densidades, proporções)      estratif. city
        ↓
[Treinamento]           [Poda]                      [Avaliação]
rpart ANOVA       →     10-fold CV              →   RMSE treino
cp = 0,001              seleciona cp ótimo           RMSE teste
                        remove splits fracos
        ↓
[Comparação]
Árvore única podada vs. Random Forest (500 árvores)
```

**Para falar:**
- O pipeline começa com dois arquivos `.tab` e termina com um HTML completo com 18 modelos
- A etapa de feature engineering criou variáveis de densidade que não existiam nos arquivos originais
- Cada etapa tem decisões metodológicas que serão detalhadas nos próximos slides

---

### Slide 10 — Divisão Treino/Teste

**Título do slide:** 80% treino / 20% teste — por que estratificar?

**Parâmetros:**

| Parâmetro | Valor |
|---|---|
| Proporção | 80% treino / 20% teste |
| Escolas no treino | ~442 |
| Escolas no teste | ~110 |
| Estratificação | Por `city` |
| Semente | `set.seed(15)` |
| Função | `caret::createDataPartition(y = city, p = 0.80)` |

**Por que estratificar por cidade?**
> Sem estratificação, em uma amostragem aleatória simples, **Laval (50 escolas no total)** poderia ter apenas 5–8 escolas no teste — insuficientes para avaliar o modelo localmente.
> Com estratificação: cada cidade mantém exatamente a proporção 80/20, garantindo representação proporcional.

**4 subconjuntos criados:**
- `train` / `test` — **com** variável `city` → modelo nacional geográfico
- `train_nocity` / `test_nocity` — **sem** `city` → isola o efeito da variável geográfica

---

### Slide 11 — Como Funciona a Árvore de Regressão

**Título do slide:** Divisão recursiva binária — minimizando o erro

**Mecanismo passo a passo:**

1. **Nó raiz:** todas as 442 escolas de treino — previsão = média global (0,546)
2. **Busca do melhor split:** para cada variável e cada valor de corte candidato:
   ```
   ΔRSS = RSS_antes − (RSS_esquerda + RSS_direita)
   ```
   O split com **maior ΔRSS** é selecionado
3. **Critério de parada:** o split só é feito se a melhoria relativa excede `cp`:
   ```
   ΔRSS / RSS_total > cp (= 0,001)
   ```
4. **Recursão:** cada sub-nó repete o processo até `minsplit = 20` ou `cp`
5. **Previsão:** cada folha prevê a **média de `active_t_prop`** das escolas que a compõem

**Exemplo com o primeiro split da árvore nacional podada:**
```
Raiz: pop_den < 2.847 km²?
    SIM → 266 escolas, média TA = 0,461 (área suburbana, menos TA)
    NÃO → 177 escolas, média TA = 0,675 (área urbana densa, mais TA)
```

---

### Slide 12 — Hiperparâmetros e Validação Cruzada

**Título do slide:** Como os hiperparâmetros foram definidos

**Tabela de hiperparâmetros:**

| Hiperparâmetro | Valor | Por quê |
|---|---|---|
| `cp` | 0,001 | Permissivo → gera árvore grande; poda define tamanho final via CV |
| `minsplit` | 20 | Default rpart — evita divisões com < 20 escolas no nó |
| `minbucket` | 6 | ≈ minsplit/3 — evita folhas com 1–2 escolas |
| `xval` | **10** | **10-fold CV — padrão da literatura** |
| `usesurrogate` | 2 | Necessário: `road_den` tem 363 NAs — usa splits substitutos |

**Como a 10-fold CV guia a poda:**
```
Treino (442 escolas) → dividido em 10 partes iguais (~44 escolas cada)
Para cada tamanho de árvore:
  → treina em 9 partes, avalia na 10ª
  → repete 10 vezes
  → calcula xerror médio
O cp com menor xerror = ponto ótimo de poda
```

**Elemento visual:** gráfico `plotcp` gerado no projeto (curva de xerror vs. cp)

---

### Slide 13 — Poda (Pruning)

**Título do slide:** Poda — regularização da árvore de decisão

**O problema:**
> Árvore completa com `cp = 0,001` aprende os dados de treino com RMSE = 0,10
> mas generaliza mal: RMSE de teste = **0,1731**
> O modelo memorizou o treino em vez de aprender o padrão real — **overfitting**

**A solução — poda via `cp` ótimo:**
```r
mincp <- model$cptable[which.min(model$cptable[,"xerror"]), "CP"]
pmodel <- prune(model, cp = mincp)
```
> Resultado: árvore com apenas **3 splits** → RMSE teste cai para **0,1621**

**Analogia com regularização:**

| Regularização em Redes Neurais | Poda em Árvores |
|---|---|
| Penalidade L1/L2 sobre pesos | Penalidade `cp` sobre splits |
| `λ` maior → modelo mais simples | `cp` maior → menos splits |
| Selecionado via validação cruzada | Selecionado via `xerror` da 10-fold CV |

> A poda é a **forma de regularização nativa da árvore** — sem ela, o modelo overfita sempre.

---

### Slide 14 — Modelos Construídos

**Título do slide:** 18 modelos — por que tantos?

**Estrutura dos modelos:**

| Modelo | Inclui `city`? | Versão |
|---|---|---|
| Nacional | Sim | Completo + Podado |
| Nacional s/ city | Não | Completo + Podado |
| Calgary | — | Completo + Podado |
| Peel Region | — | Completo + Podado |
| Toronto | — | Completo + Podado |
| Montreal | — | Completo + Podado |
| Laval | — | Completo + Podado |
| Surrey | — | Completo + Podado |
| Vancouver | — | Completo + Podado |

**Total: 18 modelos**

**Lógica dos 3 grupos:**
1. **Nacional com `city`** — captura variação geográfica como preditor
2. **Nacional sem `city`** — testa se a melhora vem da cidade ou dos outros preditores
3. **Por cidade** — modelos locais capturam padrões específicos de cada contexto urbano

---

---

## BLOCO 4 — RESULTADOS (5 min)

---

### Slide 15 — RMSE: Modelos Nacionais

**Título do slide:** Poda melhorou a generalização

**Tabela comparativa:**

| Modelo | RMSE Treino | RMSE Teste | Gap |
|---|---|---|---|
| Árvore completa (c/ city) | 0,1007 | 0,1731 | 0,0724 |
| **Árvore podada (c/ city)** | **0,1438** | **0,1621** | **0,0183** |
| Árvore completa (s/ city) | 0,1007 | 0,1731 | 0,0724 |
| Árvore podada (s/ city) | 0,1438 | 0,1621 | 0,0183 |

**Destaques para falar:**
- Poda reduziu RMSE de teste de 0,1731 → 0,1621 **(↓6%)**
- O gap treino→teste caiu de 0,072 para 0,018 — poda efetivamente controlou o overfitting
- Modelo com `city` = modelo sem `city`: a variável geográfica **não teve impacto adicional** no modelo nacional (city já estava implicitamente capturada por `pop_den` e variáveis de uso do solo)
- RMSE de 0,162 na escala de proporção significa **±16 p.p. de erro médio** na taxa de TA da escola

---

### Slide 16 — Árvore Nacional Podada (Visual)

**Título do slide:** 3 splits — o que a árvore aprendeu

**Estrutura da árvore (para desenhar/mostrar imagem):**

```
                    [Raiz]
               pop_den < 2847
              /              \
           SIM                NÃO
     (266 escolas)        (177 escolas)
     média TA = 0,46      média TA = 0,68
          |
   SumReskm < 0,26           density_pre_1960_houses < 4,7
   /          \                    /              \
 (137)        (129)            (133)              (44)
  0,40         0,52             0,64              0,77
```

**Leitura do modelo:**

| Pergunta da árvore | Interpretação |
|---|---|
| `pop_den < 2.847 hab/km²` | A escola fica em área suburbana ou urbana densa? |
| `SumReskm < 0,26 km²` | A zona de captação tem pouca área residencial? |
| `density_pre_1960_houses` | O bairro é antigo (pré-1960), mais denso e mais caminhável? |

**Para falar:**
- Pop_den = 2.847 hab/km² é aproximadamente a fronteira entre subúrbio e cidade densa
- Áreas mais densas → mais crianças caminham (TA médio = 0,68)
- Bairros históricos pré-1960 têm traçado urbano mais favorável à caminhada (quarteirões menores, menos carros)
- A árvore capturou o princípio do "New Urbanism" com apenas 3 perguntas

---

### Slide 17 — Resultados por Cidade

**Título do slide:** Modelos locais — cada cidade tem seu padrão

**Tabela RMSE por cidade:**

| Cidade | RMSE Treino | RMSE Teste | Splits podados | N treino |
|---|---|---|---|---|
| **Montreal** | 0,1250 | **0,1394** | 3 | ~92 |
| **Surrey** | 0,0769 | 0,1448 | 1 | ~45 |
| **Calgary** | 0,1065 | 0,1542 | 0 (raiz pura) | ~54 |
| **Toronto** | 0,0951 | 0,1734 | 2 | ~97 |
| **Vancouver** | 0,0802 | 0,1705 | 0 (raiz pura) | ~54 |
| **Laval** | 0,1809 | 0,1894 | 0 (raiz pura) | ~42 |
| **Peel** | 0,1094 | 0,2210 | 0 (raiz pura) | ~59 |

**Destaques:**
- **Montreal** = melhor cidade: modelo com 3 splits úteis, RMSE 0,139
- **Peel Region** = pior: RMSE 0,221 — poda resultou em nó raiz (sem preditor útil generalizável)
- **4 de 7 cidades** com poda = nó raiz: isso significa que a 10-fold CV não encontrou nenhum preditor com sinal generalizável suficiente na amostra local — o modelo nacional é mais adequado para essas cidades

**Para falar:**
- "Nó raiz puro" não é falha do algoritmo — é um sinal honesto de que a amostra local (40–55 escolas de treino) é insuficiente para encontrar padrões específicos da cidade que generalizem bem

---

### Slide 18 — Importância das Variáveis

**Título do slide:** O que mais explica o transporte ativo?

**Top 9 variáveis — Árvore nacional completa:**

| Posição | Variável | Score | Interpretação |
|---|---|---|---|
| 1 | `pop_den` | 5,02 | Densidade populacional (hab/km²) |
| 2 | `multihome_den` | 4,00 | Densidade de edifícios multifamiliares/km² |
| 3 | `child_den` | 3,68 | Densidade de crianças (0-17 anos)/km² |
| 4 | `ShapeAreakm` | 3,15 | Tamanho da zona de captação (km²) |
| 5 | `ActLivClassEnv` | 2,82 | Classificação de ambiente para vida ativa |
| 6 | `immigrant_den` | 2,79 | Densidade de imigrantes recentes/km² |
| 7 | `SumReskm` | 1,98 | Área residencial total (km²) |
| 8 | `city` | 1,15 | Cidade (variável geográfica) |
| 9 | `density_pre_1960_houses` | 1,09 | Densidade de casas pré-1960/km² |

**Elemento visual:** Dot plot gerado no projeto (`output/AT_Importance_Score_Dot_Plot.png`)

**Para falar:**
- `pop_den` lidera com folga — a densidade do bairro é o fator mais determinante do TA escolar
- `multihome_den` em 2º lugar: apartamentos e duplexes → vizinhança mais densa e caminhável
- `child_den` em 3º: onde há mais crianças, mais crianças caminham (segurança nos números?)
- Walkscore aparece mais abaixo — a densidade *construída* tem mais poder preditivo que o índice de caminhabilidade comercial
- Consistência entre modelos: as mesmas variáveis aparecem importantes em múltiplas cidades (pontos alinhados no dot plot)

---

---

## BLOCO 5 — MODIFICAÇÃO IMPLEMENTADA (4 min)

---

### Slide 19 — Problema Descoberto: Data Leakage

**Título do slide:** O modelo "trapaceava" — RMSE de 0,018 era falso

**O que é data leakage:**
> Quando o modelo tem acesso durante o treino a informações que **não estariam disponíveis** na previsão real — ou informações que são, na prática, o próprio alvo.

**O que aconteceu no nosso projeto:**

```
Arquivo original (Stata): uma versão de cada variável → sem vazamento
Nossa reconstrução (merge de .tab): coluna original + alias ambos no dataset

active_t_prop = NewActiveTProp   ← alias criado
NewActiveTProp = ??? ← ainda no dataset como preditor!
```

> O modelo aprendia a prever `active_t_prop` usando `NewActiveTProp` (valor idêntico) → RMSE artificialmente próximo de zero.

**Impacto numérico:**

| Situação | RMSE Treino | RMSE Teste |
|---|---|---|
| Com vazamento (antes) | 0,0184 | 0,0231 |
| **Sem vazamento (depois)** | **0,1438** | **0,1621** |

**Correção implementada:**
> Adicionadas 13 colunas originais à lista de exclusão do `subset()` no Rmd:
> `NewActiveTProp`, `NewActiveT`, `TotalCount`, `caroccupant`, `pedcountprop`, `bikecountprop`, `Other`, `Otherprop`, `Newbussedprop`, `Bussedprop`, `ActiveT`, `ActiveTprop`, `caroccupantprop`

---

### Slide 20 — Melhoria: Random Forest

**Título do slide:** De 1 árvore para 500 — como o ensemble generaliza melhor

**O problema com a árvore única:**
> RMSE treino = 0,10 vs. RMSE teste = 0,162 → **gap de 60%** = overfitting
> A árvore memoriza padrões do treino que não se repetem no teste

**Como o Random Forest resolve:**

```
Treino (442 escolas)
        ↓
Bootstrap #1 (reamostragem com reposição) → Árvore 1
Bootstrap #2 (reamostragem com reposição) → Árvore 2
...
Bootstrap #500                             → Árvore 500
        ↓
Previsão final = MÉDIA das 500 previsões
```

**Dois mecanismos de redução de variância:**

| Mecanismo | O que faz |
|---|---|
| **Bagging** | 500 bootstraps com ~63% das escolas cada → diversidade de treino |
| **Amostragem de variáveis** | A cada split, só m = ⌊p/3⌋ preditores são considerados → árvores menos correlacionadas |

**Fórmula:**
```
ŷ_RF(x) = (1/500) × Σ T_b(x)
```

**Para falar:**
- A variância do estimador cai com mais árvores; o viés permanece similar ao de uma árvore individual
- "1 árvore memoriza; 500 árvores generalizam" — a essência do ensemble

---

### Slide 21 — Resultado do Random Forest

**Título do slide:** RF reduz RMSE de teste em 12,6%

**Tabela comparativa final:**

| Modelo | RMSE Treino | RMSE Teste | Gap (T−t) | Melhoria vs. Árvore Podada |
|---|---|---|---|---|
| Árvore única — completa | 0,1007 | 0,1731 | 0,0724 | — |
| Árvore única — podada | 0,1438 | 0,1621 | 0,0183 | referência |
| **Random Forest (500 árvores)** | **0,0555** | **0,1417** | 0,0862 | **↓12,6%** |

**Estimativa OOB (Out-of-Bag):**
> RMSE OOB = **0,1399** ≈ RMSE teste real (0,1417)
> O RF estima sua própria performance internamente — sem precisar de conjunto de teste separado

**Top variáveis do Random Forest (%IncMSE):**

| Pos | Variável | %IncMSE |
|---|---|---|
| 1 | `pop_den` | 15,6% |
| 2 | `SumReskm` | 12,4% |
| 3 | `multihome_den` | 12,1% |
| 4 | `density_pre_1960_houses` | 11,6% |
| 5 | `child_den` | 9,3% |

**Conclusão:**
> As mesmas variáveis importantes na árvore única são as mais importantes no RF — **consistência entre métodos valida as conclusões do artigo original**.

---

---

## BLOCO 6 — CONCLUSÃO (1 min)

---

### Slide 22 — Conclusões

**Título do slide:** O que aprendemos com 552 escolas canadenses

**3 conclusões centrais:**

**1. Densidade populacional é o principal determinante do TA escolar**
> `pop_den` é a variável mais importante em todos os modelos (árvore única e RF).
> Áreas urbanas densas (> 2.847 hab/km²) têm, em média, **46% mais transporte ativo** do que áreas suburbanas.
> Implicação para políticas: investir em densificação urbana e design de bairros é mais efetivo do que intervenções pontuais de segurança viária.

**2. Modelos por cidade revelam padrões locais distintos**
> Montreal generaliza bem (RMSE 0,139); Peel não encontra sinal local (RMSE 0,221 = pior que o nacional).
> Não existe uma fórmula única: o ambiente construído afeta o TA de formas diferentes em cada contexto cultural, climático e urbano canadense.

**3. Random Forest generaliza melhor, mas mantém as mesmas variáveis importantes**
> RF reduz o RMSE de teste em 12,6% (0,162 → 0,142) — melhoria prática significativa para planejamento urbano.
> A consistência entre árvore e RF no ranking de importância **valida as conclusões do artigo**: pop_den, multihome_den, child_den e density_pre_1960_houses são robustamente os determinantes centrais do transporte ativo escolar canadense.

---

*Fim dos slides — Projeto IA 2026.1*
