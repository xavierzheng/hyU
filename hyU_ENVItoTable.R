#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)
# AIM: extract the XY location and reflectance by R

# test if there is at least one argument: if not, return an error
if (length(args)!=3) {
stop("Usage: hyU_ENVItoTable.R <dat_file> <hdr_file> <output_file_name>", call.=FALSE)
}

# define output name
SaveOUT <- as.character(x = args[3])
CORE <- as.numeric(8)


# library ---------------------------------------
library(hyperSpec)
library(data.table)
setDTthreads(threads = CORE)


# extract reflectance ---------------------------

df <- hyperSpec::read.ENVI(file = args[1], headerfile = args[2])

df2 <- cbind(df$x, df$y, df$spc)

df2 <- data.table::as.data.table(df2)

colnames(df2) <- c("x", "y", df@wavelength)

data.table::fwrite(
    df2,
    file = SaveOUT, 
    quote = F, 
    sep = "\t",
    col.names = T,
    row.names = F, 
    nThread = CORE
)
