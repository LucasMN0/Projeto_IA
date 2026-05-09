cat("=== Preparação do Dataset CHASE ===\n")
cat("Lendo arquivos de origem (somente leitura — valores intocáveis)...\n\n")

schools <- read.delim(
  "DadosProjetoIA/CAN_Surveyed_Schools.tab",
  sep = "\t", header = TRUE, stringsAsFactors = FALSE
)

catchment <- read.delim(
  "DadosProjetoIA/CAN_Schools_Catchment.tab",
  sep = "\t", header = TRUE, stringsAsFactors = FALSE
)

cat("CAN_Surveyed_Schools:", nrow(schools), "linhas,", ncol(schools), "colunas\n")
cat("CAN_Schools_Catchment:", nrow(catchment), "linhas,", ncol(catchment), "colunas\n\n")

# Remover 3 linhas com Schoolid vazio (sem dados válidos — ID inválido)
n_before <- nrow(schools)
schools <- schools[schools$Schoolid != "" & !is.na(schools$Schoolid), ]
cat("Linhas removidas (Schoolid vazio):", n_before - nrow(schools), "\n\n")

# LEFT JOIN por Schoolid
merged <- merge(schools, catchment, by = "Schoolid", all.x = TRUE, suffixes = c("", ".catch"))
cat("Após merge:", nrow(merged), "linhas,", ncol(merged), "colunas\n\n")

# Corrige duplicata de capitalização gerada pelo merge (Walkscore vs walkscore)
if ("Walkscore" %in% names(merged) && "walkscore" %in% names(merged)) {
  merged$Walkscore <- NULL
}

# Colunas renomeadas (alias) — valores originais intactos
merged$myid            <- merged$Schoolid
merged$Schoolid        <- NULL  # Remove original para não entrar como preditor fator no rpart
merged$walkscore       <- merged$Walkscore
merged$lico_at_da      <- merged$LICOATda
merged$enrollment      <- merged$enrolment
merged$active_t        <- merged$NewActiveT
merged$active_t_prop   <- merged$NewActiveTProp
merged$total_count     <- merged$TotalCount
merged$caroccup        <- merged$caroccupant
merged$caroccup_prop   <- merged$caroccupantprop
merged$pedcount        <- merged$pedcount
merged$pedcount_prop   <- merged$pedcountprop
merged$bikecount       <- merged$bikecount
merged$bikecount_prop  <- merged$bikecountprop
merged$other           <- merged$Other
merged$other_prop      <- merged$Otherprop
merged$bussed          <- merged$bussed
merged$bussed_prop     <- merged$Newbussedprop
merged$years           <- merged$CHASEYEAR

# Variável city: numérica preservando a ordem do Stata usada no Rmd
# (Calgary=1, Laval=2, Montreal=3, Peel=4, Toronto=5, Surrey=6, Vancouver=7)
# Os arquivos .tab usam códigos de 3 letras (CAL, LAV, MTL, PEL, TOR, SUR, VAN)
# Mapear códigos 3-letras para nomes completos (exatamente como o Rmd filtra: city == "Calgary" etc.)
city_name_map <- c(CAL="Calgary", LAV="Laval", MTL="Montreal",
                   PEL="Peel", TOR="Toronto", SUR="Surrey", VAN="Vancouver")

# Identificar coluna City correta (pode ser City ou City.catch após merge)
city_col <- if ("City" %in% names(merged)) "City" else "City.catch"
merged$city <- as.factor(city_name_map[merged[[city_col]]])

cat("Distribuição de city:\n")
print(table(merged$city, useNA = "always"))
cat("\n")

# Variáveis de catchment (renomeadas)
merged$area              <- merged$ShapeAreakm
merged$pop2016           <- merged$Pop2016
merged$pop2016_0to17yrs  <- merged$AG017
merged$school_num        <- merged$NbrSchools
merged$road_sum          <- merged$roadcovkm
merged$intersection_num  <- merged$SUMIntersection
merged$signals_num       <- merged$NbrTrafSignals
merged$highway_km        <- merged$Highwaykm
merged$majorroad_km      <- merged$MajorRoadkm
merged$minorroad_km      <- merged$MinorRoadkm
merged$multihome_num     <- merged$STDMulti
merged$immigrant_recent  <- merged$ISPH1116
merged$house_pre60       <- merged$OPDbPC60Less
merged$com_area          <- merged$SumComkm
merged$open_area         <- merged$SumOpenAreakm
merged$park_area         <- merged$SumParkkm
merged$res_area          <- merged$SumReskm
merged$ind_area          <- merged$SumIndkm
merged$gov_area          <- merged$SumGouvkm
merged$bikeclass_1       <- merged$BikeClass01
merged$bikeclass_2       <- merged$BikeClass02
merged$bikeclass_3       <- merged$BikeClass03
merged$bikeclass_total   <- merged$BikeClassAll
merged$speedhump_roads_sum  <- merged$SpeedHumpkm
merged$circles_num          <- merged$NbrTrafficCircles
merged$narrows_num          <- merged$NbrMidBlockNarrowings
merged$extensions_num       <- merged$NbrCurbExtension
merged$diverters_num        <- merged$NbrDiverter
merged$crosswalks_num       <- merged$NbrCrosswalk
merged$flashing_num         <- merged$NbrFlashingCrosswalk
merged$speedsigns_num       <- merged$NbrSpeedActivatedSign
merged$raised_crosswalk_num <- merged$NbrRaisedCrosswalk

# Variáveis derivadas de densidade (novos cálculos — colunas-base intocáveis)
merged$pop_den          <- merged$Pop2016    / merged$ShapeAreakm
merged$child_den        <- merged$AG017      / merged$ShapeAreakm
merged$child_pro        <- merged$AG017      / merged$Pop2016
merged$road_den         <- merged$roadcovkm  / merged$ShapeAreakm
merged$guard_den        <- merged$NbrCrossingGuard / merged$ShapeAreakm
merged$highway_pro      <- merged$Highwaykm  / merged$roadcovkm
merged$majorroad_pro    <- merged$MajorRoadkm / merged$roadcovkm
merged$minorroad_pro    <- merged$MinorRoadkm / merged$roadcovkm
merged$multihome_den    <- merged$STDMulti   / merged$ShapeAreakm
merged$immigrant_pro    <- merged$ISPH1116   / merged$Pop2016
merged$immigrant_den    <- merged$ISPH1116   / merged$ShapeAreakm
merged$bikeclass_pro    <- merged$BikeClassAll / merged$roadcovkm
merged$diverters_den    <- merged$NbrDiverter / merged$ShapeAreakm
merged$speedsigns_den   <- merged$NbrSpeedActivatedSign / merged$ShapeAreakm
merged$raised_crosswalk_den <- merged$NbrRaisedCrosswalk / merged$ShapeAreakm
merged$enrollment_pro   <- merged$enrolment  / merged$AG017

# Variáveis derivadas usadas nas árvores do artigo (splits S1–S7, mmc1.pdf)
merged$density_intersections      <- merged$SUMIntersection  / merged$ShapeAreakm
merged$proportion_industrial_area <- merged$SumIndkm         / merged$ShapeAreakm
merged$density_pre_1960_houses    <- merged$OPDbPC60Less     / merged$ShapeAreakm
merged$proportion_government_area <- merged$SumGouvkm        / merged$ShapeAreakm
merged$proportion_commercial_area <- merged$SumComkm         / merged$ShapeAreakm
merged$density_major_roads        <- merged$MajorRoadkm      / merged$ShapeAreakm
merged$density_bicycle_class      <- merged$BikeClassAll     / merged$ShapeAreakm
merged$density_curb_extensions    <- merged$NbrCurbExtension / merged$ShapeAreakm

# Variável province derivada da city string
province_map <- c(
  CAL = "AB",
  LAV = "QC", MTL = "QC",
  PEL = "ON", TOR = "ON",
  SUR = "BC", VAN = "BC"
)
merged$province <- province_map[merged[[city_col]]]

# Colisões não disponíveis publicamente (confirmado na documentação CHASE)
merged$collisions_child <- NA_real_
merged$collisions_adult <- NA_real_

cat("Resumo da variável-alvo (active_t_prop):\n")
print(summary(merged$active_t_prop))
cat("\n")

cat("Verificação de variáveis-chave (NAs):\n")
key_vars <- c("myid", "city", "active_t_prop", "walkscore", "pop_den",
              "child_den", "enrollment", "immigrant_den", "multihome_den",
              "school_num", "road_den")
na_counts <- sapply(merged[, key_vars], function(x) sum(is.na(x)))
print(na_counts)
cat("\n")

# Salvar dataset consolidado
saveRDS(merged, "DadosProjetoIA/School_and_Catchment_Data.rds")
cat("Dataset salvo em: DadosProjetoIA/School_and_Catchment_Data.rds\n")
cat("Total de linhas:", nrow(merged), "| Total de colunas:", ncol(merged), "\n")
cat("\n=== Preparação concluída com sucesso ===\n")
