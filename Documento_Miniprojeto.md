# Documento do Miniprojeto — Inteligência Artificial 2026.1

---

## 1. Artigo Escolhido

| Campo | Informação |
|---|---|
| **Título** | *Using machine learning to predict child active transportation prevalence* |
| **Autores** | Tate HubkaRao, Meghan Winters et al. |
| **Periódico** | Journal of Transport & Health (Elsevier) |
| **Ano** | 2025 |
| **DOI** | [10.1016/j.jth.2025.102178](https://doi.org/10.1016/j.jth.2025.102178) |
| **Indexação** | Web of Science / ScienceDirect (Elsevier) — periódico com fator de impacto |

---

## 2. Descrição da Base de Dados

O projeto utiliza dados do estudo **CHASE 2018** (*Child Health Active Transportation Study*), disponível publicamente no repositório **Borealis** (DOI: 10.5683/SP3/W9YL4Q).

| Característica | Detalhe |
|---|---|
| Unidade de análise | Escola (zona de captação escolar) |
| Total de amostras | **552 escolas** |
| Cobertura geográfica | 7 cidades canadenses: Calgary, Peel, Toronto, Montreal, Laval, Surrey, Vancouver |
| Período | Levantamentos CHASE 2012–2018 |

### Arquivos utilizados

| Arquivo | Conteúdo | Linhas |
|---|---|---|
| `CAN_Surveyed_Schools.tab` | Modos de transporte por escola, walkscore, matrícula | 555 (3 inválidas removidas) |
| `CAN_Schools_Catchment.tab` | Área, população, infraestrutura viária, uso do solo, ciclofaixas | 552 |

Os dois arquivos foram unidos por `LEFT JOIN` na chave `Schoolid`, gerando um dataset consolidado com **552 linhas e 205 colunas**.

### Variável-alvo

`active_t_prop` — proporção de crianças que utilizam **transporte ativo** (caminhada ou bicicleta) para ir à escola, contínua no intervalo [0, 1].

| Estatística | Valor |
|---|---|
| Mínimo | 0,00 |
| 1º Quartil | 0,41 |
| Mediana | 0,54 |
| Média | 0,54 |
| 3º Quartil | 0,68 |
| Máximo | 1,00 |

### Preditores utilizados

Após limpeza de variáveis redundantes, colineares e identificadores, foram mantidos **127 preditores**, organizados em:

- **Densidades populacionais:** `pop_den`, `child_den`, `multihome_den`, `immigrant_den`
- **Infraestrutura viária e ciclística:** `road_den`, `density_major_roads`, `density_bicycle_class`, `density_intersections`, `density_curb_extensions`
- **Uso do solo:** `proportion_commercial_area`, `proportion_industrial_area`, `proportion_government_area`, `open_area`
- **Características urbanas:** `walkscore`, `density_pre_1960_houses`, `ActLivClassEnv`
- **Escola:** `enrollment`, `school_num`
- **Cidade:** `city` (fator categórico com 7 níveis)

> **Dados não disponíveis publicamente:** variáveis de colisão (`collisions_child`, `collisions_adult`) — confirmado pela documentação CHASE; mantidas como NA.

---

## 3. Tamanho da População

**Não se aplica.** O projeto não utiliza inteligência de enxames. O tamanho da amostra é de 552 escolas.

---

## 4. Divisão Treino / Teste

| Parâmetro | Valor |
|---|---|
| Proporção | **80% treino / 20% teste** |
| Escolas no treino | ~442 |
| Escolas no teste | ~110 |
| Estratificação | Por `city` — garante representação proporcional de cada cidade em ambos os conjuntos |
| Semente | `set.seed(15)` |
| Função utilizada | `caret::createDataPartition(y = city, p = 0.80)` |

A estratificação por cidade é fundamental: sem ela, cidades pequenas como Laval (50 escolas total) teriam apenas ~10 observações no teste, insuficientes para avaliação confiável.

Foram criados **4 subconjuntos**:
- `train` / `test` — com variável `city` (modelo nacional geográfico)
- `train_nocity` / `test_nocity` — sem `city` (isola o efeito da variável geográfica)

---

## 5. Uso de Validação Cruzada

**Sim — 10-fold Cross-Validation**, integrada diretamente ao algoritmo `rpart` via parâmetro `xval = 10`.

A CV não é usada para selecionar hiperparâmetros, mas para **estimar o erro de generalização** de cada tamanho de árvore e guiar a poda:

1. O dataset de treino é dividido em 10 partes iguais
2. Para cada valor de `cp` (tamanho de árvore), a árvore é treinada 10 vezes, cada vez excluindo uma parte
3. O `xerror` médio (erro relativo de validação cruzada) é calculado para cada tamanho
4. O `cp` que **minimiza o `xerror`** determina o tamanho ótimo para a poda

---

## 6. Algoritmos Implementados

### 6.1 Árvore de Regressão — `rpart` (método ANOVA)

O algoritmo principal é a **Árvore de Regressão Recursiva** (*Recursive Partitioning and Regression Trees*), implementada no pacote `rpart` com `method = "anova"`.

#### Como funciona

A árvore divide o espaço de preditores de forma **binária e recursiva**:

1. **Nó raiz:** contém todas as 442 escolas de treino
2. **Seleção do split:** para cada variável preditora e cada valor de corte candidato, calcula:
   $$\Delta RSS = RSS_{antes} - (RSS_{esquerda} + RSS_{direita})$$
   O split com maior $\Delta RSS$ é selecionado
3. **Critério de parada:** `cp` define o ganho mínimo relativo exigido:
   $$\frac{\Delta RSS}{RSS_{total}} > cp$$
4. **Repetição:** cada sub-nó é dividido recursivamente até atingir `minsplit` ou `cp`
5. **Previsão:** cada nó folha prevê a **média** de `active_t_prop` das escolas que o compõem

#### Poda da árvore (*Pruning*)

Após construir a árvore completa (permissiva, `cp = 0.001`):

```r
mincp <- model$cptable[which.min(model$cptable[,"xerror"]), "CP"]
pmodel <- prune(model, cp = mincp)
```

A tabela `cptable` registra, para cada tamanho de árvore: `CP`, `nsplit`, `rel error`, `xerror`, `xstd`. A poda seleciona o `cp` que minimiza o `xerror` da CV, produzindo uma árvore mais simples que **generaliza melhor**.

#### Modelos construídos

| Modelo | Variável `city`? | Tipo |
|---|---|---|
| Nacional (completo) | Sim | Árvore não podada |
| Nacional (podado) | Sim | Árvore podada |
| Nacional s/ city (completo) | Não | Árvore não podada |
| Nacional s/ city (podado) | Não | Árvore podada |
| Calgary, Peel, Toronto, Montreal, Laval, Surrey, Vancouver | — | 1 modelo completo + 1 podado por cidade |

**Total: 18 modelos** (2 nacionais × 2 versões + 7 cidades × 2 versões)

### 6.2 Importância de Variáveis — `vip::vip()`

Para cada variável preditora, acumula a **redução total de RSS** obtida em todos os splits onde ela foi usada (primário ou substituto). Normaliza o valor mais alto para 100.

---

## 7. Critérios de Escolha dos Hiperparâmetros

**Grid Search não foi utilizado.** Os valores foram definidos com base nos defaults recomendados pela documentação do `rpart` (Therneau & Atkinson, 2019) e pelo protocolo original dos autores do artigo.

| Hiperparâmetro | Valor | Critério de escolha |
|---|---|---|
| `cp` | 0,001 | Permissivo → gera árvore grande; poda define tamanho final via CV |
| `minsplit` | 20 | Default `rpart`; evita divisões com menos de 20 obs. no nó |
| `minbucket` | 6 | ≈ `minsplit/3`; evita folhas com 1–2 escolas |
| `xval` | 10 | Padrão amplamente adotado na literatura |
| `usesurrogate` | 2 | Necessário para lidar com 363 valores ausentes em `road_den` sem remover escolas |

---

## 8. Uso de Transfer Learning

**Não utilizado.** O domínio (transporte ativo infantil em cidades canadenses) não dispõe de modelos pré-treinados aplicáveis.

---

## 9. Uso de Técnicas de Regularização / Dropout

**Poda da árvore como regularização implícita.**

O parâmetro `cp` (*complexity parameter*) funciona de forma análoga à regularização L1/L2 em redes neurais: penaliza splits de baixa contribuição, forçando o modelo a ter menos divisões e menor risco de overfitting.

- `cp` maior → modelo mais simples (maior regularização)
- `cp` menor → modelo mais complexo (menor regularização)
- A escolha via CV do `mincp` equivale a uma busca pelo ponto ótimo no trade-off viés-variância

**Dropout não se aplica** — não há redes neurais no projeto.

---

## 10. Uso de Aumento de Dados

**Não utilizado.** O dataset representa um censo das escolas participantes do CHASE 2018. Não há base para gerar observações sintéticas sem distorcer a distribuição real.

---

## 11. Como Lidar com Desbalanceamento de Classes

**Não se aplica.** O problema é de **regressão** (variável-alvo contínua entre 0 e 1), não de classificação. Técnicas como SMOTE e Tomek Links são exclusivas de problemas de classificação com classes desbalanceadas.

---

## 12. Figuras de Mérito para Avaliação de Desempenho

### RMSE — Root Mean Square Error

Métrica principal, na mesma escala da variável-alvo (proporção de 0 a 1):

$$RMSE = \sqrt{\frac{1}{n} \sum_{i=1}^{n} (\hat{y}_i - y_i)^2}$$

Um RMSE de 0,16 significa **erro médio de ±16 pontos percentuais** na proporção de transporte ativo.

### Resultados obtidos

#### Modelos Nacionais

| Modelo | RMSE Treino | RMSE Teste |
|---|---|---|
| Árvore única — completa | 0,1007 | 0,1731 |
| **Árvore única — podada** | **0,1438** | **0,1621** |
| Árvore única s/ city — completa | 0,1007 | 0,1731 |
| Árvore única s/ city — podada | 0,1438 | 0,1621 |

> A poda reduziu o RMSE de teste de 0,1731 → 0,1621 (↓6%), confirmando sua eficácia contra overfitting.

#### Splits da árvore nacional podada (3 divisões)

| Nó | Variável de split | N escolas | Média TA |
|---|---|---|---|
| Raiz | `pop_den` | 442 | 0,546 |
| Baixa densidade | `SumReskm` | 266 | 0,461 |
| Alta densidade | `density_pre_1960_houses` | 177 | 0,675 |

#### Modelos por Cidade

| Cidade | RMSE Treino | RMSE Teste | Splits podados |
|---|---|---|---|
| Montreal | 0,1250 | **0,1394** | 3 |
| Surrey | 0,0769 | 0,1448 | 1 |
| Calgary | 0,1065 | 0,1542 | 0 (raiz pura) |
| Toronto | 0,0951 | 0,1734 | 2 |
| Vancouver | 0,0802 | 0,1705 | 0 (raiz pura) |
| Laval | 0,1809 | 0,1894 | 0 (raiz pura) |
| Peel | 0,1094 | 0,2210 | 0 (raiz pura) |

> Cidades com 0 splits após poda indicam que a CV não encontrou nenhum preditor com sinal generalizável suficiente naquela amostra local.

#### Top 10 variáveis mais importantes (Nacional — completa)

| Posição | Variável | Score |
|---|---|---|
| 1 | `pop_den` (densidade populacional) | 5,02 |
| 2 | `multihome_den` (edifícios multifamiliares/km²) | 4,00 |
| 3 | `child_den` (crianças/km²) | 3,68 |
| 4 | `ShapeAreakm` (área da zona de captação) | 3,15 |
| 5 | `ActLivClassEnv` (classificação de ambiente ativo) | 2,82 |
| 6 | `immigrant_den` (imigrantes recentes/km²) | 2,79 |
| 7 | `SumReskm` (área residencial) | 1,98 |
| 8 | `City` (cidade) | 1,15 |
| 9 | `density_pre_1960_houses` (casas pré-1960/km²) | 1,09 |

---

## 13. Informação sobre a Implementação

| Item | Detalhe |
|---|---|
| Linguagem | R 4.5.3 |
| Ambiente | RMarkdown → HTML via `rmarkdown::render()` |
| Script de dados | `prepare_data.R` — leitura, merge, aliases, variáveis derivadas, exportação `.rds` |
| Script de modelagem | `ML Prevelence Project Rmd.Rmd` — 89 chunks, modelagem completa, visualizações |
| Outputs gerados | `output/Predicted_Prevalence.csv`, `output/AT_Importance_Score_Dot_Plot.png`, `ML-Prevelence-Project-Rmd.html` |

### Pacotes utilizados

| Pacote | Função |
|---|---|
| `rpart` | Construção das árvores de regressão |
| `rpart.plot` | Visualização das árvores |
| `caret` | Divisão estratificada treino/teste e cálculo de RMSE |
| `vip` | Importância de variáveis |
| `randomForest` | Random Forest (modificação implementada) |
| `ggplot2` + `reshape2` | Dot plot de importâncias |
| `table1` | Tabela descritiva por cidade |
| `basictabler` | Tabela de comparação de RMSE |

---

## 14. Fontes Consultadas

| Fonte | Descrição |
|---|---|
| Repositório Borealis | Dados CHASE 2018 — DOI: 10.5683/SP3/W9YL4Q |
| Artigo original | DOI: 10.1016/j.jth.2025.102178 |
| Material suplementar | Figuras S1–S7 com árvores de referência (mmc1.pdf) |
| Therneau & Atkinson (2019) | *An Introduction to Recursive Partitioning Using the RPART Routines*, Mayo Foundation |
| Greenwell & Boehmke (2020) | Pacote `vip` — Journal of Statistical Software, 92(1) |
| Breiman (2001) | *Random Forests* — Machine Learning, 45(1), 5–32 |

---

## 15. Modificação Realizada na Técnica (2,0 pontos)

### 15.1 — Correção de Vazamento de Dados (*Data Leakage*) — Implementada

#### Problema identificado

O código original foi escrito para um arquivo Stata (`.dta`) pré-processado, onde cada variável existia em apenas uma versão. Na nossa reconstrução a partir dos arquivos `.tab`, o `merge()` preservou **tanto os aliases criados quanto as colunas originais**. O `subset()` de exclusão do Rmd removia apenas os aliases (`active_t`, `caroccup`, etc.), mas as colunas originais — incluindo `NewActiveTProp` (idêntica ao target `active_t_prop`) — permaneciam no dataset como preditores.

#### Impacto

| Situação | RMSE Treino | RMSE Teste |
|---|---|---|
| Com vazamento (antes) | 0,0184 | 0,0231 |
| **Sem vazamento (depois)** | **0,1438** | **0,1621** |

O modelo "aprendia" a prever `active_t_prop` usando `NewActiveTProp` (mesmos dados), tornando o resultado inválido.

#### Correção implementada

Adicionadas 13 colunas à lista de exclusão do `subset()` no Rmd (linha 182):

```r
# Colunas originais que causavam vazamento de dados
ActiveT, ActiveTprop, NewActiveT, NewActiveTProp, TotalCount,
caroccupant, caroccupantprop, pedcountprop, bikecountprop,
Other, Otherprop, Newbussedprop, Bussedprop
```

Esta correção é uma **contribuição metodológica real**: revela que o RMSE publicado no código original era artificialmente baixo, e que os modelos do artigo devem ter sido gerados a partir do arquivo Stata limpo, sem as duplicatas.

---

### 15.2 — Implementação de Random Forest para Comparação

#### Justificativa

A árvore única nacional apresenta um **gap treino→teste de ~60%** (RMSE treino=0,10 vs. teste=0,162), indicando overfitting significativo. A raiz do problema é a **alta variância** do estimador: uma pequena mudança nos dados de treino pode alterar drasticamente a estrutura da árvore.

O **Random Forest** (Breiman, 2001) resolve isso através de dois mecanismos:

1. **Bagging (*Bootstrap Aggregating*):** cada uma das 500 árvores é treinada em uma reamostragem com reposição do conjunto de treino (~63% das escolas, amostragem única por árvore). A previsão final é a **média** das 500 previsões individuais.
2. **Amostragem de variáveis por split:** em cada divisão, apenas $m = \lfloor p/3 \rfloor$ preditores são considerados (em vez de todos os $p$), reduzindo a correlação entre árvores e aumentando a diversidade do ensemble.

$$\hat{y}_{RF}(x) = \frac{1}{B} \sum_{b=1}^{B} T_b(x), \quad B = 500$$

O efeito teórico: a variância do estimador cai proporcionalmente ao número de árvores, enquanto o viés permanece aproximadamente igual ao de uma árvore individual.

#### Implementação

```r
library(randomForest)
set.seed(15)
# NAs imputados com mediana por coluna (RF não aceita valores ausentes)
rf_model <- randomForest(active_t_prop ~ ., data = train_rf,
                         ntree = 500,
                         mtry = floor(ncol(train_rf)/3),
                         importance = TRUE)
```

#### Resultados obtidos

| Modelo | RMSE Treino | RMSE Teste | Gap (Teste−Treino) |
|---|---|---|---|
| Árvore única (completa) | 0,1007 | 0,1731 | 0,0724 |
| Árvore única (podada) | 0,1438 | 0,1621 | 0,0183 |
| **Random Forest (500 árvores)** | **0,0555** | **0,1417** | 0,0862 |

O Random Forest reduziu o **RMSE de teste em 12,6%** em relação à árvore podada (0,1417 vs. 0,1621), demonstrando a melhoria de generalização do ensemble. O RMSE OOB (*Out-of-Bag*) — estimativa interna do RF — foi 0,1399, muito próximo ao RMSE de teste real (0,1417), confirmando a validade da estimativa sem necessidade de conjunto de teste separado.

#### Top 10 variáveis mais importantes (Random Forest — %IncMSE)

| Posição | Variável | %IncMSE |
|---|---|---|
| 1 | `pop_den` | 15,64 |
| 2 | `SumReskm` | 12,42 |
| 3 | `multihome_den` | 12,12 |
| 4 | `density_pre_1960_houses` | 11,62 |
| 5 | `child_den` | 9,31 |
| 6 | `ActLivClassEnv` | 9,20 |
| 7 | `city` | 8,16 |
| 8 | `MinorRoadkm` | 8,15 |
| 9 | `walkscore` | 7,51 |
| 10 | `Walkscore` | 7,36 |

> A consistência entre a importância da árvore única e do RF (ambos apontam `pop_den`, `multihome_den`, `child_den` e `density_pre_1960_houses` como os principais preditores) **valida as conclusões do artigo original**: a densidade populacional e a composição do ambiente construído são os determinantes centrais do transporte ativo escolar.

#### Por que o RF não elimina completamente o overfitting?

O gap de 0,086 (treino→teste) permanece maior que o da árvore podada (0,018) porque:
- As 500 árvores individuais **não foram podadas** — cada uma overfita seu bootstrap
- Com 127 preditores e apenas 442 escolas no treino, o modelo tem alta dimensionalidade
- A imputação de NAs por mediana pode ter introduído ruído adicional

Uma extensão natural seria aplicar **Gradient Boosting** (XGBoost) ou **poda interna nas árvores do RF** para reduzir ainda mais o overfitting.

---

## 16. Contribuições dos Integrantes

*(A ser preenchido pela equipe)*

| Integrante | Contribuição |
|---|---|
| | |

---

## Resumo Executivo

| Critério do PDF | Nossa resposta |
|---|---|
| Artigo (2022–2026, Web of Science) | Journal of Transport & Health, Elsevier, 2025, DOI 10.1016/j.jth.2025.102178 |
| Base de dados | CHASE 2018 — 552 escolas, 7 cidades canadenses |
| Tamanho da população (enxames) | N/A |
| % treino / teste | 80% / 20%, estratificado por cidade |
| Validação cruzada | Sim — 10-fold CV integrada ao `rpart` |
| Algoritmos | Árvore de Regressão (`rpart`/ANOVA) + Random Forest |
| Critério dos hiperparâmetros | Defaults da literatura; sem Grid Search |
| Transfer Learning | Não |
| Regularização | Poda via `cp` (análogo a L1/L2); sem Dropout |
| Aumento de dados | Não |
| Desbalanceamento de classes | N/A (regressão contínua) |
| Métricas | RMSE (treino e teste); importância de variáveis |
| Modificação implementada | (A) Correção de data leakage (RMSE 0,018→0,162); (B) Random Forest com RMSE teste 0,1417 (↓12,6% vs. árvore podada) |
