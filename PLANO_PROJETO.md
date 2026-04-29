# Plano: Reconstrução do Dataset e Execução do Projeto ML de Prevalência de Transporte Ativo

---

## ⛔ REGRA ABSOLUTA — INTEGRIDADE DOS DADOS

> **OS VALORES DOS DADOS NÃO PODEM SER MODIFICADOS EM NENHUMA HIPÓTESE.**
>
> - **Permitido:** renomear colunas (alias), criar novas colunas derivadas por cálculo entre colunas existentes
> - **Proibido:** alterar, imputar, arredondar, filtrar ou transformar qualquer valor numérico ou categórico presente nos arquivos `.tab` originais
> - **Se qualquer operação de escrita nos arquivos originais for iniciada por engano:** cancelar imediatamente, não salvar, e reportar ao usuário exatamente o que foi tentado

---

## Contexto

O artigo científico analisa fatores que influenciam a diminuição de crianças que vão à escola de forma ativa (caminhando/bicicleta). O código Rmd espera um arquivo Stata (`.dta`) consolidado chamado `School and Catchment Data.dta`, que não existe localmente. Os dados estão disponíveis em `/home/lucas/Projeto_IA/DadosProjetoIA/` como 4 arquivos `.tab` do estudo CHASE 2018, referenciados no repositório Borealis: `https://borealisdata.ca/dataset.xhtml?persistentId=doi:10.5683/SP3/W9YL4Q`.

---

## Prioridade 0 — Status do Repositório Borealis

A URL do repositório (`https://borealisdata.ca/dataset.xhtml?persistentId=doi:10.5683/SP3/W9YL4Q`) foi inacessível durante o planejamento por restrições de rede local. **Ao iniciar a implementação, tentar novamente o acesso** para:
- Confirmar se os arquivos `.tab` locais são idênticos aos publicados (nomes e tamanhos)
- Verificar se há arquivos adicionais não presentes localmente

**Resultado esperado:** com base na documentação CHASE lida localmente (README + PDF de metodologias), todos os 8 arquivos públicos estão disponíveis localmente. Não há dados de colisão no repositório (ver seção abaixo).

---

## Diagnóstico Completo

### Ambiente
- **R 4.5.3** instalado ✓, **Python 3.10.12** instalado ✓

### Pacotes R — Necessários vs. Instalados
| Pacote | Status |
|--------|--------|
| conflicted, plyr, rpart, rpart.plot, caret, haven, tree, vip, table1, ggplot2, data.table, reshape2 | ✓ Instalado |
| **sf** | ✗ Faltando |
| **randomForest** | ✗ Faltando |
| **partykit** | ✗ Faltando |
| **basictabler** | ✗ Faltando |
| **tidyverse** | ✗ Faltando (meta-pacote; componentes individuais como dplyr, ggplot2 estão presentes) |

### Arquivos de Dados Locais
| Arquivo | Linhas (local) | Linhas (README oficial) | Diferença |
|---------|---------------|------------------------|-----------|
| `CAN_Surveyed_Schools.tab` | **554** | 552 | +2 ⚠️ |
| `CAN_Schools_Catchment.tab` | 552 | 552 | ✓ |
| `CAN_Schools_500m.tab` | 552 | 552 | ✓ |
| `CAN_Schools_1000m.tab` | 552 | 552 | ✓ |

> ⚠️ **Discrepância de 2 linhas em CAN_Surveyed_Schools.tab:** o arquivo local tem 2 escolas a mais que a versão publicada oficial. Pode ser uma versão mais recente ou versão de trabalho pré-publicação. Os valores não serão alterados — a discrepância será registrada no relatório final.

### Convenção de Nomenclatura
O README oficial usa underscores: `ISPH_11_16`, `STD_Multi`, `AG_0_17`. Os arquivos `.tab` locais removem os underscores: `ISPH1116`, `STDMulti`, `AG017`. **São os mesmos dados** — apenas convenção de escrita diferente.

---

## Confirmações da Documentação CHASE (PDF + README)

### 1. Dados de Colisão — INDISPONÍVEIS e IRRECUPERÁVEIS ✓
- **Fonte:** base de dados separada com n=74.523 vítimas, obtida de portais municipais (não está no repositório Borealis)
- **Vancouver e Surrey:** sem dados de colisão mesmo no estudo original — confirmado pelo PDF: *"We don't have any collision data in Vancouver and Surrey"*
- **Conclusão:** `collisions_child = NA` e `collisions_adult = NA` para todas as escolas. Esta é a única opção possível sem acesso à base municipal restrita

### 2. Variáveis do Statistics Canada — Já pré-processadas por ArcGIS ✓
Os valores de censo nos arquivos `.tab` foram obtidos por interseção espacial proporcional (Pairwise Intersect + Dissolve + SUM no ArcGIS Pro). Não são valores brutos de censo — já estão ponderados pela área de sobreposição entre Dissemination Areas e as zonas de captação. Nosso cálculo de densidades (ex: `AG017 / ShapeAreakm`) opera sobre esses valores já processados.

Variáveis confirmadas pelo PDF:
| Nome oficial (README) | Nome no arquivo local | Descrição |
|----------------------|-----------------------|-----------|
| ISPH_11_16 | ISPH1116 | Imigrantes recentes (<5 anos) |
| OPDbPC_60_Less | OPDbPC60Less | Casas pré-1960 |
| STD_Multi | STDMulti | Edificações multifamiliares (aptos, duplexes) |
| AG_0_17 | AG017 | Crianças <18 anos |
| AG_1_17 | AG117 | Crianças 1-17 anos |
| Pop2016 | Pop2016 | População total 2016 |

> **Nota:** `Pop_Km2` (densidade pré-calculada) existe na camada DA do Statistics Canada, mas NÃO está nos arquivos de buffer/catchment. Por isso calcularemos `pop_den = Pop2016 / ShapeAreakm` manualmente.

### 3. Uso do Solo — Fonte DMTI Spatial ✓
Variáveis de área (km²) obtidas por interseção entre camada DMTI e polígonos de zona de captação. Todos os `Sum_*_km` já estão no arquivo `CAN_Schools_Catchment.tab`.

### 4. Infraestrutura de Ciclismo — 3 Classes confirmadas ✓
- Classe 01: alta qualidade (ciclovias protegidas, pistas segregadas)
- Classe 02: intermediária (caminhos multiuso, rotas sinalizadas)
- Classe 03: baixa (faixas pintadas, tráfego compartilhado)

---

## Estratégia de Reconstrução

**Arquivos utilizados:** `CAN_Surveyed_Schools.tab` + `CAN_Schools_Catchment.tab`
- Justificativa: o título do arquivo `.dta` original é "School and **Catchment** Data" e a Tabela 1 do artigo cita "Characteristics of **Catchment Zone**, by city/region"
- Junção: LEFT JOIN por `Schoolid`

**Arquivos em standby:** `CAN_Schools_500m.tab`, `CAN_Schools_1000m.tab` — não utilizados a menos que o Borealis revele algo diferente

---

## Mapeamento Completo de Colunas

> **Apenas nomes são alterados. Valores permanecem intactos.**

### De `CAN_Surveyed_Schools.tab`
| Coluna original (intocável) | Variável no Rmd | Fonte confirmada |
|-----------------------------|-----------------|-----------------|
| Schoolid | myid | CHASE survey |
| City | city (+ nova coluna numérica) | CHASE survey |
| Walkscore | walkscore | Walk Score® |
| LICOATda | lico_at_da | Statistics Canada |
| enrolment | enrollment | CHASE survey |
| NewActiveT | active_t | CHASE survey (versão limpa) |
| NewActiveTProp | active_t_prop | CHASE survey (versão limpa) |
| TotalCount | total_count | CHASE survey |
| caroccupant | caroccup | CHASE survey |
| caroccupantprop | caroccup_prop | CHASE survey |
| pedcount | pedcount | CHASE survey |
| pedcountprop | pedcount_prop | CHASE survey |
| bikecount | bikecount | CHASE survey |
| bikecountprop | bikecount_prop | CHASE survey |
| Other | other | CHASE survey |
| Otherprop | other_prop | CHASE survey |
| bussed | bussed | CHASE survey |
| Newbussedprop | bussed_prop | CHASE survey (versão limpa) |
| CHASEYEAR | years | CHASE survey |

### De `CAN_Schools_Catchment.tab` (após junção)
| Coluna original (intocável) | Variável no Rmd | Fonte confirmada |
|-----------------------------|-----------------|-----------------|
| ShapeAreakm | area | ArcGIS (geometria) |
| Pop2016 | pop2016 | Statistics Canada |
| AG017 | pop2016_0to17yrs | Statistics Canada |
| NbrSchools | school_num | DMTI / Open Data |
| roadcovkm | road_sum | National Road Network |
| SUMIntersection | intersection_num | National Road Network |
| NbrTrafSignals | signals_num | Municipal Open Data |
| NbrCrossingGuard | (usado só para guard_den) | Municipal Open Data |
| Highwaykm | highway_km | National Road Network |
| MajorRoadkm | majorroad_km | National Road Network |
| MinorRoadkm | minorroad_km | National Road Network |
| STDMulti | multihome_num | Statistics Canada |
| ISPH1116 | immigrant_recent | Statistics Canada |
| OPDbPC60Less | house_pre60 | Statistics Canada |
| SumComkm | com_area | DMTI Spatial |
| SumOpenAreakm | open_area | DMTI Spatial |
| SumParkkm | park_area | DMTI Spatial |
| SumReskm | res_area | DMTI Spatial |
| SumIndkm | ind_area | DMTI Spatial |
| SumGouvkm | gov_area | DMTI Spatial |
| BikeClass01 | bikeclass_1 | Municipal Open Data |
| BikeClass02 | bikeclass_2 | Municipal Open Data |
| BikeClass03 | bikeclass_3 | Municipal Open Data |
| BikeClassAll | bikeclass_total | Municipal Open Data |
| SpeedHumpkm | speedhump_roads_sum | Municipal Open Data |
| NbrTrafficCircles | circles_num | Municipal Open Data |
| NbrMidBlockNarrowings | narrows_num | Municipal Open Data |
| NbrCurbExtension | extensions_num | Municipal Open Data |
| NbrDiverter | diverters_num | Municipal Open Data |
| NbrCrosswalk | crosswalks_num | Municipal Open Data |
| NbrFlashingCrosswalk | flashing_num | Municipal Open Data |
| NbrSpeedActivatedSign | speedsigns_num | Municipal Open Data |
| NbrRaisedCrosswalk | raised_crosswalk_num | Municipal Open Data |

### Novas colunas derivadas (cálculos — não alteram dados originais)
| Nova variável | Cálculo | Justificativa |
|---------------|---------|---------------|
| pop_den | Pop2016 / ShapeAreakm | Pop_Km2 não está nos arquivos de catchment |
| child_den | AG017 / ShapeAreakm | Não pré-calculado |
| child_pro | AG017 / Pop2016 | Não pré-calculado |
| road_den | roadcovkm / ShapeAreakm | Não pré-calculado |
| guard_den | NbrCrossingGuard / ShapeAreakm | Não pré-calculado |
| highway_pro | Highwaykm / roadcovkm | Não pré-calculado |
| majorroad_pro | MajorRoadkm / roadcovkm | Não pré-calculado |
| minorroad_pro | MinorRoadkm / roadcovkm | Não pré-calculado |
| multihome_den | STDMulti / ShapeAreakm | Não pré-calculado |
| immigrant_pro | ISPH1116 / Pop2016 | Não pré-calculado |
| immigrant_den | ISPH1116 / ShapeAreakm | Não pré-calculado |
| bikeclass_pro | BikeClassAll / roadcovkm | Não pré-calculado |
| diverters_den | NbrDiverter / ShapeAreakm | Não pré-calculado |
| speedsigns_den | NbrSpeedActivatedSign / ShapeAreakm | Não pré-calculado |
| raised_crosswalk_den | NbrRaisedCrosswalk / ShapeAreakm | Não pré-calculado |
| enrollment_pro | enrolment / AG017 | Não pré-calculado |
| province | mapeado de City: Calgary→AB, Laval/Montreal→QC, Peel/Toronto→ON, Surrey/Vancouver→BC | Derivado |
| collisions_child | NA — base municipal restrita, não disponível no CHASE | Confirmado pela documentação |
| collisions_adult | NA — base municipal restrita, não disponível no CHASE | Confirmado pela documentação |

> **Nota city:** criar coluna numérica via `match(City, c("Calgary","Laval","Montreal","Peel","Toronto","Surrey","Vancouver"))` → valores 1-7, mantendo a coluna `City` original intacta

---

## Passos de Implementação

### Passo 0 — Tentar acesso ao Borealis
Verificar se o repositório está acessível. Se sim, comparar arquivos. Se não, documentar e prosseguir.

### Passo 1 — Instalar pacotes R faltantes
**Arquivo criado:** `/home/lucas/Projeto_IA/install_packages.R`
```r
install.packages(c("sf", "randomForest", "partykit", "basictabler", "tidyverse"),
                 repos = "https://cloud.r-project.org")
```

### Passo 2 — Criar script de preparação dos dados
**Arquivo criado:** `/home/lucas/Projeto_IA/prepare_data.R`

Sequência (sem tocar nos valores dos arquivos originais):
1. `read.delim()` nos dois arquivos `.tab` com `sep="\t"`
2. LEFT JOIN por `Schoolid`
3. Criar colunas renomeadas (sem apagar as originais)
4. Criar variáveis derivadas de densidade
5. Criar coluna numérica `city` via `match()`
6. Adicionar `collisions_child = NA`, `collisions_adult = NA`
7. Imprimir diagnóstico: `nrow()`, `names()`, `table(city)`, `summary(active_t_prop)`
8. `saveRDS()` → `DadosProjetoIA/School_and_Catchment_Data.rds`

### Passo 3 — Modificar o Rmd (apenas paths)
**Arquivo modificado:** `/home/lucas/Projeto_IA/ML Prevelence Project Rmd.Rmd`
- **Linha 85:** `read_dta("C:/Users/tateh/...")` → `readRDS("DadosProjetoIA/School_and_Catchment_Data.rds")`
- **Linha 916:** path Windows do `ggsave` → `"graphs/AT_Importance_Score_Dot_Plot.png"`
- **Linha 960:** path Windows do `write.csv` → `"output/Predicted_Prevalence.csv"`
- Adicionar `dir.create("graphs", showWarnings=FALSE)` e `dir.create("output", showWarnings=FALSE)` no início

### Passo 4 — Executar e validar
```bash
cd /home/lucas/Projeto_IA
Rscript install_packages.R
Rscript prepare_data.R
Rscript -e "rmarkdown::render('ML Prevelence Project Rmd.Rmd')"
```

---

## Arquivos Críticos
| Operação | Arquivo | Restrição |
|----------|---------|-----------|
| Leitura **somente** | `DadosProjetoIA/CAN_Surveyed_Schools.tab` | Não modificar |
| Leitura **somente** | `DadosProjetoIA/CAN_Schools_Catchment.tab` | Não modificar |
| Criação | `install_packages.R` | — |
| Criação | `prepare_data.R` | — |
| Modificação mínima | `ML Prevelence Project Rmd.Rmd` (linhas 85, 916, 960) | Só paths |
| Criação (output) | `DadosProjetoIA/School_and_Catchment_Data.rds` | Novo arquivo gerado |

---

## Verificação Final
1. `prepare_data.R` imprime ~552–554 linhas, 7 valores únicos em `city`, `active_t_prop` entre 0 e 1
2. HTML renderizado do Rmd contém:
   - Histograma de `active_t_prop`
   - Tabela 1 com 7 cidades (com `collisions_child = NA` nas colunas relevantes)
   - 14 árvores de regressão (2 nacionais + 7 por cidade × 2 versões)
   - Tabelas de RMSE nacionais e por cidade
   - Gráfico de importância de variáveis
