## Builds the bundled example datasets from the CSV files shipped with the
## Python CORA package (GPL-3.0-or-later, https://github.com/PoliUniLu/cora).
src <- commandArgs(trailingOnly = TRUE)[[1L]]

swiss_minaret <- utils::read.csv(file.path(src, "SwissMinaret.csv"))
gross_carvin <- utils::read.csv(file.path(src, "GrossCarvin2011.csv"), sep = ";",
                                stringsAsFactors = FALSE)
mccluskey <- utils::read.csv(file.path(src, "McCluskeyF1F2.csv"), sep = ";")
bergschlosser <- utils::read.csv(file.path(src, "bergschlosser_2008_MV_3Out.csv"),
                                 stringsAsFactors = FALSE)

save(swiss_minaret, file = "data/swiss_minaret.rda", version = 2,
     compress = "xz")
save(gross_carvin, file = "data/gross_carvin.rda", version = 2, compress = "xz")
save(mccluskey, file = "data/mccluskey.rda", version = 2, compress = "xz")
save(bergschlosser, file = "data/bergschlosser.rda", version = 2,
     compress = "xz")
