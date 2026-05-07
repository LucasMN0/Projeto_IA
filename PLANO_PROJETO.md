# Plano de Conteúdo — Apresentação do Miniprojeto
### Inteligência Artificial 2026.1

> Este documento é um guia de estudo completo. Cada bloco explica o conteúdo, fornece os dados reais do projeto e orienta o que falar na apresentação. Use-o para estudar, escrever seu relatório individual e montar seus slides.

---

## BLOCO 1 — O Artigo Escolhido

### O que é e por que foi escolhido

O artigo se chama **"Factors associated with active transportation to school among Canadian children: a national cross-sectional study using recursive partitioning"**, publicado em 2025 no **Journal of Transport & Health** (Elsevier), periódico indexado no **Web of Science** com fator de impacto reconhecido. O DOI é `10.1016/j.jth.2025.102178`.

O autor principal do código é **Tate HubkaRao**, pesquisador da área de saúde pública e mobilidade urbana. O artigo investiga **quais características do ambiente urbano influenciam a proporção de crianças que vão à escola caminhando ou de bicicleta** em sete cidades canadenses.

### Por que esse tema importa

Transporte ativo (TA) — caminhar ou pedalar para a escola — é um dos poucos momentos do dia em que crianças acumulam atividade física de forma natural, sem depender de academia ou esporte organizado. Pesquisas mostram que crianças que usam TA têm menor risco de obesidade, melhor saúde cardiovascular e maior independência. Porém, nas últimas décadas, a proporção de crianças que fazem isso caiu drasticamente em cidades ocidentais por conta da expansão urbana, do aumento do tráfego e da percepção de insegurança.

O artigo usa **Machine Learning** para identificar *quais fatores do bairro* — densidade populacional, ciclofaixas, walkscore, tipo de uso do solo — realmente fazem diferença, e quais têm mais impacto em cada cidade.

### Por que a técnica de ML usada é relevante

O artigo usa **Árvore de Regressão Recursiva** (*Recursive Partitioning*), que pertence à família de algoritmos de aprendizado supervisionado. A escolha é justificada porque:
- A variável-alvo é **contínua** (proporção de 0 a 1), não uma categoria
- Árvores são **interpretáveis**: qualquer pessoa consegue seguir o caminho de decisão e entender por que uma escola tem alta ou baixa proporção de TA
- O algoritmo captura **interações não-lineares** entre variáveis (ex.: walkscore alto importa mais em cidades com alta densidade)

---

## BLOCO 2 — A Base de Dados

### O estudo CHASE 2018

Os dados vêm do estudo **CHASE** (*Child Health Active Transportation Study*), um levantamento nacional canadense realizado entre 2012 e 2018. O dataset foi disponibilizado publicamente no repositório **Borealis** (DOI: 10.5683/SP3/W9YL4Q).

### Estrutura dos dados

O projeto usa **dois arquivos** que foram unidos por `LEFT JOIN` na chave `Schoolid`:

**Arquivo 1 — `CAN_Surveyed_Schools.tab`**
Contém dados coletados diretamente nas escolas. Informações como: quantas crianças chegam de carro, a pé, de bicicleta, de ônibus; walkscore do bairro; número de alunos matriculados.

**Arquivo 2 — `CAN_Schools_Catchment.tab`**
Contém dados da **zona de captação** — a área geográfica em torno de cada escola de onde os alunos provavelmente vêm. Informações como: área total (km²), população, número de crianças, extensão de vias, km de ciclofaixas, área residencial/comercial/industrial/parques, densidade de intersecções, casas pré-1960.

Após o merge e remoção de 3 escolas com ID inválido, o dataset final tem:
- **552 escolas** (linhas)
- **205 colunas** no total (após criação de variáveis derivadas)
- **7 cidades:** Calgary (125), Surrey (96), Toronto (76), Montreal (67), Vancouver (67), Peel (71), Laval (50)

### A variável-alvo

`active_t_prop` = proporção de crianças que usam transporte ativo por escola.

| Estatística | Valor |
|---|---|
| Mínimo | 0,00 (nenhuma criança usa TA) |
| 1º Quartil | 0,41 |
| Mediana | 0,54 |
| Média | 0,54 |
| 3º Quartil | 0,68 |
| Máximo | 1,00 (todas as crianças usam TA) |

A distribuição é aproximadamente normal em torno de 0,54, o que justifica o uso de regressão (e não modelos para dados extremos ou classificação).

### Variáveis preditoras — as mais importantes para entender

Após remover variáveis redundantes, identificadores e outras formas do desfecho, foram mantidos **~132 preditores**. As mais relevantes:

| Variável | O que mede | Por que importa |
|---|---|---|
| `pop_den` | Habitantes por km² | Bairros mais densos tendem a ter mais TA — tudo fica mais perto |
| `multihome_den` | Edifícios multifamiliares por km² | Apartamentos/sobrados → maior densidade → mais TA |
| `child_den` | Crianças por km² | Mais crianças no bairro → mais demanda por rotas seguras a pé |
| `walkscore` | Índice 0–100 de caminhabilidade | Mede proximidade a serviços — diretamente ligado ao TA |
| `density_pre_1960_houses` | Casas anteriores a 1960 por km² | Bairros antigos têm ruas menores e quadras curtas → mais caminháveis |
| `ActLivClassEnv` | Classificação do ambiente de vida ativa | Score composto de fatores favoráveis ao TA |
| `density_major_roads` | Km de vias arteriais por km² | Mais vias rápidas → menos seguro para crianças → menos TA |
| `density_bicycle_class` | Km de ciclofaixas por km² | Infraestrutura para ciclistas → mais crianças de bike |
| `city` | Cidade (Calgary a Vancouver) | Cada cidade tem padrões urbanos e culturais diferentes |

### Variáveis que NÃO estão disponíveis

`collisions_child` e `collisions_adult` — número de colisões com pedestres/ciclistas — são **100% ausentes (NA)** em todos os 552 registros. Isso porque os dados de colisão vêm de bancos municipais com acesso restrito e **não foram incluídos no repositório público**. O artigo original usava esses dados, o que explica a diferença em alguns modelos (ex.: Montreal usa `density_adult_collisions` como split no artigo, mas não no nosso modelo).

---

## BLOCO 3 — Metodologia de Machine Learning

### 3.1 Pré-processamento dos dados

Antes de modelar, o dataset passa por limpeza em dois scripts:

**`prepare_data.R`** — faz o merge dos dois arquivos `.tab`, cria aliases de variáveis (nomes mais legíveis), e calcula **variáveis derivadas de densidade**:
```
pop_den       = Pop2016 / ShapeAreakm
child_den     = AG017   / ShapeAreakm
multihome_den = STDMulti / ShapeAreakm
```
Essas divisões normalizam os valores pela área da zona, tornando as escolas comparáveis independentemente do tamanho de sua zona de captação.

**No Rmd** — o `subset()` remove do dataset de modelagem todas as variáveis problemáticas:
- Identificadores (`myid`, `years`, `province`)
- Outras formas do desfecho (`active_t`, `total_count`, modos individuais de transporte)
- Variáveis com 100% NA (`collisions_child`, `collisions_adult`)
- Variáveis redundantes com as derivadas (`pop2016` bruto, quando `pop_den` já existe)

### 3.2 Divisão Treino/Teste — Por que estratificar?

```r
set.seed(15)
split_ind <- createDataPartition(y = prevelence_df$city, p = 0.80, list = FALSE)
```

A divisão é **80% treino / 20% teste**, estratificada pela cidade. Isso significa que cada cidade mantém a mesma proporção 80/20 nos dois conjuntos.

**Por que isso é necessário?** Laval tem apenas 50 escolas. Sem estratificação, uma divisão aleatória poderia colocar 48 no treino e 2 no teste — insuficiente para qualquer avaliação. Com estratificação, Laval fica com ~40 no treino e ~10 no teste.

O `set.seed(15)` garante que qualquer pessoa que rodar o código obterá **exatamente a mesma divisão**, tornando os resultados reprodutíveis.

### 3.3 A Árvore de Regressão — Como funciona de verdade

A ideia central: **dividir as escolas em grupos cada vez mais homogêneos**, onde as escolas dentro de cada grupo têm proporções de TA semelhantes.

**Passo a passo do algoritmo:**

**1. Nó raiz** — todas as 442 escolas de treino. A média de `active_t_prop` é 0,546.

**2. Busca do melhor split** — o algoritmo testa, para cada uma das 132 variáveis, todos os valores possíveis de corte. Para cada par (variável, corte), divide as 442 escolas em dois grupos e calcula:
$$\Delta RSS = RSS_{antes} - (RSS_{esquerda} + RSS_{direita})$$
O RSS é a soma dos quadrados das diferenças entre cada escola e a média do grupo. O split que **maximizar** o ΔRSS é o escolhido.

**3. Primeiro split — `pop_den`** — a densidade populacional é a variável que mais reduz o RSS. Divide em:
- Escolas com baixa densidade (266 escolas, média TA = 0,461)
- Escolas com alta densidade (177 escolas, média TA = 0,675)

Isso já mostra uma verdade intuitiva: bairros mais densos têm muito mais crianças indo à escola a pé ou de bike.

**4. Repetição recursiva** — cada sub-grupo é dividido novamente usando o mesmo critério, criando uma estrutura de árvore.

**5. Critério de parada** — o parâmetro `cp = 0.001` exige que cada novo split reduza o RSS total em pelo menos 0,1%. Se nenhuma divisão cumpre esse critério, o nó vira uma **folha** (previsão final = média das escolas naquele grupo).

**6. Previsão** — para prever o TA de uma escola nova, ela percorre a árvore seguindo os splits até chegar a uma folha. O valor previsto é a média das escolas de treino naquela folha.

### 3.4 Validação Cruzada — O que é e para que serve

Junto com a construção da árvore, o `rpart` roda automaticamente uma **10-fold cross-validation**:

1. Divide o conjunto de treino em 10 partes iguais (~44 escolas cada)
2. Treina 10 versões da árvore, cada vez deixando uma parte de fora
3. Testa cada versão na parte deixada de fora
4. Calcula o **xerror** médio — o erro de validação cruzada — para cada tamanho de árvore

Isso gera uma tabela `cptable` mostrando como o erro muda à medida que a árvore fica menor. O **objetivo** é identificar o ponto onde simplificar a árvore não piora mais o erro — esse é o tamanho ideal.

### 3.5 Poda (Pruning) — Por que simplificar melhora?

Uma árvore grande demais **memoriza os dados de treino** em vez de aprender padrões gerais. Isso é overfitting: funciona bem no treino, mas mal em dados novos.

```r
mincp <- model$cptable[which.min(model$cptable[,"xerror"]), "CP"]
pmodel <- prune(model, cp = mincp)
```

A poda seleciona o `cp` com menor `xerror` e remove todos os splits com complexidade abaixo desse valor. É como a regularização L1/L2 em redes neurais: penaliza a complexidade para melhorar a generalização.

**Resultado no projeto:**

| Modelo | RMSE Treino | RMSE Teste |
|---|---|---|
| Árvore completa | 0,1007 | 0,1731 |
| Árvore podada | 0,1438 | 0,1621 |

A poda **aumentou** o erro de treino (de 0,10 para 0,14) mas **diminuiu** o erro de teste (de 0,173 para 0,162). Isso é exatamente o comportamento correto — o modelo deixou de memorizar e passou a generalizar.

### 3.6 Hiperparâmetros — O que cada um faz

| Parâmetro | Valor | Efeito prático |
|---|---|---|
| `cp = 0.001` | Threshold mínimo de ganho | Permissivo — gera árvore grande para depois podar |
| `minsplit = 20` | Mín. obs. para tentar dividir um nó | Evita splits em grupos muito pequenos |
| `minbucket = 6` | Mín. obs. em cada folha | Evita que uma folha tenha só 1 ou 2 escolas |
| `xval = 10` | Folds da CV | Padrão da literatura; 10 é robusto sem ser lento demais |
| `usesurrogate = 2` | Lida com valores ausentes | Necessário: `road_den` tem 363 NAs — sem isso, 363 escolas seriam excluídas |

**Não foi usado Grid Search.** Os valores foram definidos com base nos padrões recomendados pela documentação do `rpart` e pelo protocolo do artigo original.

---

## BLOCO 4 — Resultados

### 4.1 Modelos Nacionais

Foram construídos 4 modelos nacionais (completo + podado, com e sem a variável `city`):

| Modelo | RMSE Treino | RMSE Teste |
|---|---|---|
| Nacional c/ city (completo) | 0,1007 | 0,1731 |
| **Nacional c/ city (podado)** | **0,1438** | **0,1621** |
| Nacional s/ city (completo) | 0,1007 | 0,1731 |
| Nacional s/ city (podado) | 0,1438 | 0,1621 |

**Observação:** os modelos com e sem `city` tiveram RMSE idêntico. Isso aconteceu porque `city` não apareceu nos splits da árvore podada — as variáveis de densidade já capturam implicitamente as diferenças entre cidades.

**A árvore nacional podada tem 3 divisões:**

```
Nó raiz: 442 escolas — média TA = 0,546
│
├─ pop_den baixo → 266 escolas, média TA = 0,461 (bairros menos densos)
│   └─ SumReskm → divide por área residencial
│
└─ pop_den alto → 177 escolas, média TA = 0,675 (bairros mais densos)
    └─ density_pre_1960_houses → divide por casas antigas
```

Interpretação: a proporção de TA é muito maior em bairros densos com casas antigas — tipicamente bairros históricos com ruas estreitas, quadras curtas e comércios misturados com residências.

### 4.2 Modelos por Cidade

| Cidade | RMSE Treino | RMSE Teste | Splits podados | Interpretação |
|---|---|---|---|---|
| Montreal | 0,1250 | **0,1394** | 3 | Melhor generalização — padrão urbano mais homogêneo |
| Surrey | 0,0769 | 0,1448 | 1 | Bom no treino, só 1 split sobrevive à poda |
| Calgary | 0,1065 | 0,1542 | 0 | CV não encontrou preditor generalizável |
| Toronto | 0,0951 | 0,1734 | 2 | Resultado próximo ao nacional |
| Vancouver | 0,0802 | 0,1705 | 0 | 0 splits — alta variabilidade local |
| Laval | 0,1809 | 0,1894 | 0 | Apenas 50 escolas — amostra pequena demais |
| Peel | 0,1094 | 0,2210 | 0 | Pior RMSE — padrão suburbano menos previsível |

**O que significa "0 splits após poda"?** A cross-validation concluiu que nenhuma divisão do dataset de treino generaliza para dados novos. O modelo simplesmente prevê a média de TA de toda a cidade para qualquer escola.

### 4.3 Importância das Variáveis

| Posição | Variável | O que significa |
|---|---|---|
| 1 | `pop_den` | Densidade populacional — determinante central |
| 2 | `multihome_den` | Densidade de edifícios multifamiliares |
| 3 | `child_den` | Densidade de crianças no bairro |
| 4 | `ShapeAreakm` | Tamanho da zona de captação |
| 5 | `ActLivClassEnv` | Classificação de ambiente de vida ativa |
| 6 | `immigrant_den` | Densidade de imigrantes recentes |
| 7 | `SumReskm` | Área residencial total |
| 8 | `City` | Cidade |
| 9 | `density_pre_1960_houses` | Casas construídas antes de 1960 |

**Conclusão geral:** o ambiente construído — especialmente a densidade e a composição habitacional — é mais determinante para o TA do que infraestrutura específica como ciclofaixas ou semáforos.

---

## BLOCO 5 — Modificações Implementadas (2,0 pontos)

### 5.1 Correção de Vazamento de Dados (Data Leakage)

#### O que é data leakage?

Vazamento de dados ocorre quando informações que não deveriam estar disponíveis no momento da previsão "escapam" para os preditores do modelo. O resultado é um modelo com desempenho artificialmente excelente — porque está "trapaceando".

#### O que aconteceu no projeto

O código original foi escrito para um arquivo Stata que tinha uma única cópia de cada variável. Na nossa reconstrução em R, fizemos um `merge()` dos dois arquivos `.tab` e criamos **aliases** (nomes alternativos) para as variáveis, mas sem apagar as colunas originais.

O `subset()` de exclusão do Rmd removia apenas os aliases (`active_t`, `caroccup`, etc.), mas as **colunas originais continuavam no dataset** — incluindo `NewActiveTProp`, que é **idêntica** à variável-alvo `active_t_prop`.

Resultado: o modelo aprendia a prever `active_t_prop` usando `NewActiveTProp` (os mesmos dados com outro nome):

| Situação | RMSE Treino | RMSE Teste |
|---|---|---|
| Com vazamento (antes) | 0,0184 | 0,0231 |
| **Sem vazamento (depois)** | **0,1438** | **0,1621** |

#### Como foi corrigido

Identificamos e adicionamos à lista de exclusão as 13 colunas problemáticas:

```r
ActiveT, ActiveTprop, NewActiveT, NewActiveTProp, TotalCount,
caroccupant, caroccupantprop, pedcountprop, bikecountprop,
Other, Otherprop, Newbussedprop, Bussedprop
```

---

### 5.2 Implementação de Random Forest

#### Por que a árvore única tem overfitting?

A árvore nacional completa tem RMSE treino=0,10 e teste=0,173 — gap de 72%. A poda reduz para 0,14/0,162 (gap de 12%). Mas ainda existe overfitting porque **uma única árvore tem alta variância**: uma pequena mudança nos dados de treino pode alterar completamente sua estrutura.

#### Como o Random Forest resolve isso

O **Random Forest** (Breiman, 2001) combina 500 árvores de regressão por dois mecanismos:

**Bagging (Bootstrap Aggregating):**
- Cada árvore é treinada em uma **reamostragem com reposição** do conjunto de treino
- Cada bootstrap contém ~63% das escolas originais
- Escolas diferentes ficam em diferentes bootstraps → cada árvore aprende uma perspectiva levemente diferente

**Amostragem de variáveis por split:**
- Em cada divisão, só `m = p/3` preditores são considerados (em vez de todos os 132)
- Isso força as árvores a serem **diversas entre si**

**Previsão final:**
$$\hat{y}_{RF}(x) = \frac{1}{500} \sum_{b=1}^{500} T_b(x)$$

A média de 500 previsões tem muito menos variância que qualquer previsão individual.

**OOB Error:** as escolas que não caíram no bootstrap de uma árvore servem como seu "teste" interno. O RF agrega esses erros para estimar o erro de generalização sem precisar de conjunto de teste separado.

#### Resultados obtidos

| Modelo | RMSE Treino | RMSE Teste | OOB RMSE |
|---|---|---|---|
| Árvore única (completa) | 0,1007 | 0,1731 | — |
| Árvore única (podada) | 0,1438 | 0,1621 | — |
| **Random Forest (500 árvores)** | **0,0555** | **0,1417** | **0,1399** |

O Random Forest reduziu o RMSE de teste de 0,1621 → 0,1417 — **melhoria de 12,6%**.

#### Top variáveis RF — consistência com a árvore única

| Posição | Variável | %IncMSE | Na árvore única também? |
|---|---|---|---|
| 1 | `pop_den` | 15,64 | Sim (nº 1) |
| 2 | `SumReskm` | 12,42 | Sim |
| 3 | `multihome_den` | 12,12 | Sim (nº 2) |
| 4 | `density_pre_1960_houses` | 11,62 | Sim (nº 9) |
| 5 | `child_den` | 9,31 | Sim (nº 3) |
| 6 | `ActLivClassEnv` | 9,20 | Sim (nº 5) |
| 7 | `city` | 8,16 | Sim (nº 8) |
| 8 | `walkscore` | 7,51 | Sim |

A consistência entre os dois algoritmos é a evidência mais forte de validade: as mesmas variáveis que importam para a árvore única também importam para o ensemble de 500 árvores. Isso **valida as conclusões do artigo original**.

---

## BLOCO 6 — Respondendo os Critérios do PDF

| Critério | Como atendemos |
|---|---|
| Artigo 2022–2026, Web of Science | Journal of Transport & Health (Elsevier), 2025, DOI 10.1016/j.jth.2025.102178 |
| Descrição da base de dados | CHASE 2018: 552 escolas, 7 cidades, dois `.tab` do Borealis |
| Tamanho da população (enxames) | N/A — não é inteligência de enxames |
| % treino/teste | 80% / 20%, estratificado por cidade |
| Validação cruzada | Sim — 10-fold CV integrada ao `rpart` via `xval = 10` |
| Algoritmos | Árvore de Regressão (`rpart`/ANOVA) + Random Forest |
| Critério dos hiperparâmetros | Defaults da literatura; sem Grid Search |
| Transfer Learning | Não utilizado |
| Regularização / Dropout | Poda via `cp` (análogo a L1/L2); sem Dropout |
| Aumento de dados | Não utilizado |
| Desbalanceamento de classes | N/A — problema de regressão contínua |
| Figuras de mérito | RMSE treino/teste para 9 modelos; importância de variáveis |
| Modificação (2 pts) | (A) Correção de data leakage; (B) Random Forest com melhoria de 12,6% |
| Implementação | R 4.5.3, RMarkdown → HTML; `prepare_data.R` + `ML Prevelence Project Rmd.Rmd` |
| Fontes | Borealis, artigo original, Therneau & Atkinson (2019), Breiman (2001) |

---

## BLOCO 7 — Guia para o Relatório Individual

Use os tópicos abaixo como roteiro. Desenvolva cada um com suas próprias palavras:

**Introdução** — contexto (saúde infantil, urbanismo), apresentação do artigo, por que ML é adequado aqui.

**Base de Dados** — CHASE 2018 com os números reais (552 escolas, 7 cidades), o que é `active_t_prop`, estatísticas descritivas.

**Metodologia** — como funciona a Árvore de Regressão de forma intuitiva, por que se divide em treino/teste, por que se poda, o que é a validação cruzada.

**Resultados** — tabela de RMSE reais, o que significa RMSE de 0,162, o que os 3 splits da árvore nacional dizem sobre o TA.

**Modificação** — o data leakage (o que foi, impacto: 0,018 → 0,162, como foi corrigido), o Random Forest (por que é melhor, resultado: 0,162 → 0,142).

**Conclusão** — densidade e composição do bairro são os determinantes centrais do TA; RF confirma e melhora as conclusões; limitação: dados de colisão ausentes.

---

## Referências

1. HubkaRao, T. et al. (2025). *Factors associated with active transportation to school among Canadian children*. Journal of Transport & Health. DOI: 10.1016/j.jth.2025.102178

2. CHASE Study Data (2018). Borealis Repository. DOI: 10.5683/SP3/W9YL4Q

3. Therneau, T. & Atkinson, B. (2019). *An Introduction to Recursive Partitioning Using the RPART Routines*. Mayo Foundation.

4. Greenwell, B. & Boehmke, B. (2020). Variable Importance Plots — vip Package. *The R Journal*, 14(1).

5. Breiman, L. (2001). Random Forests. *Machine Learning*, 45(1), 5–32.
