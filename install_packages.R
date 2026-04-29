options(repos = c(
  CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"
))

pkgs <- c("sf", "randomForest", "partykit", "basictabler", "tidyverse",
          "rmarkdown", "htmlwidgets", "mvtnorm", "libcoin", "inum")

to_install <- pkgs[!pkgs %in% rownames(installed.packages())]

if (length(to_install) > 0) {
  cat("Instalando:", paste(to_install, collapse = ", "), "\n")
  install.packages(to_install, dependencies = TRUE)
} else {
  cat("Todos os pacotes já estão instalados.\n")
}
