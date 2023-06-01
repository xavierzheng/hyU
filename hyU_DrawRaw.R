#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)
# AIM: extract the XY location and reflectance by R

# test if there is at least one argument: if not, return an error
if (length(args)!=2) {
  stop("Usage: hyU_DrawRaw.R <tsv table from hyU_ENVItoTable.R> <output_file>", call.=FALSE)
}

# define output name----------------------------------
SaveOUT <- as.character(x = args[2])
CORE <- as.numeric(4)

# library ------------------------------------------
library(data.table)
library(tidyverse)
library(scattermore)
library(cowplot)
library(RColorBrewer)

setDTthreads(threads = CORE)

# read -------------------------------------------
print("# read data table ==============================")
Sys.time()
df <- data.table::fread(
  file = args[1], 
  header = T, sep = "\t", nThread = CORE
)
Sys.time()


print("# Drawing ======================================")
Sys.time()

plot_p <- df %>%
  ggplot2::ggplot(
    aes(
      x = x, 
      y = y, 
      color = `701.13`
    )
  )+
  scattermore::geom_scattermore(
    size = 0.05
  )+
  ggplot2::scale_color_distiller(
    palette = "Greens"
  )+
  ggplot2::scale_x_continuous(
    expand = c(0, 0)
  )+
  ggplot2::scale_y_continuous(
    expand = c(0, 0)
  )+
  ggplot2::coord_cartesian(
    xlim = c(0, NA),
    ylim = c(0, NA)
  )+
  ggplot2::theme_classic()

print("# Save plot ------------------------")
Sys.time()
cowplot::ggsave2(
  plot = plot_p, 
  filename = SaveOUT, 
  width = 3.5,
  height = 8
)
Sys.time()
