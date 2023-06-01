#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)
# AIM: extract the XY location and reflectance by R

# test if there is at least one argument: if not, return an error
if (length(args)!=3) {
  stop("Usage: hyU.PredictScanWholeImage.R <tsv table from hyU_ENVItoTable.R> <uwot model location> <output_prefix>", call.=FALSE)
}

# define everything-----------------------------------------
SaveOUT_prefix <- as.character(x = args[3])
CORE <- as.numeric(8)


library(cowplot)
library(viridis)
library(RColorBrewer)
library(data.table)
library(tidyverse)
library(uwot)

setDTthreads(threads = CORE)

print("# reading whole data, need long time =================")
Sys.time()
df <- fread(args[1], header = T, sep = "\t", nThread = CORE)
Sys.time()

print("# read umap model, need long long long time ============================================")
Sys.time()
model_df_part1_dcast <- uwot::load_uwot(
  file = args[2],
  verbose = T
)
Sys.time()

print("# run for loop =======================")
RANGE_Y <- c(1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000)

lapply(RANGE_Y, FUN = function(NAM){
  
  START_Y <- as.numeric(NAM)
  END_Y <- as.numeric(NAM+1000) # fix window !!!!!
  
  df_part1 <- df[y > START_Y & y < END_Y,]
  
  print("# Normalized =========================")
  print(Sys.time())
  df_part1_melt <- df_part1 %>%
    data.table::melt.data.table(
      id.vars = c("x", "y")
    ) 
  
  df_part1_norm <- df_part1_melt[,.(variable, normal = ( value - min(value))/(max(value) - min(value))), by = .(x, y)]
  print(Sys.time())
  rm(df_part1_melt)
  
  df_part1_dcast <- data.table::dcast.data.table(
    x + y ~ variable, data = df_part1_norm, value.var = "normal", fill = 0
  )
  print(Sys.time())
  rm(df_part1_norm)
  
  print("# Apply uwot model =========================")
  print(Sys.time())
  set.seed(1459)
  uwot_predict <- uwot::umap_transform(
    model = model_df_part1_dcast,
    X = df_part1_dcast[,3:dim(df_part1_dcast)[2]],
    n_threads = 8, 
    verbose = T
  )
  
  gc()
  
  print("# Visulize the umap result ========================================")
  print(Sys.time())
  df_umap <- cbind(df_part1_dcast[,1:2], uwot_predict)
  
  colnames(df_umap) <- c("x", "y", "umap1", "umap2")
  
  # define function ================
  draw_umap <- function(INPUT_DATA, DIMENSION){
    
    INPUT_DATA %>%
      ggplot2::ggplot(
        aes(
          x = x, 
          y = y, 
          color = get(DIMENSION)
        )
      )+
      scattermore::geom_scattermore(
        size = 0.05
      )+
      viridis::scale_color_viridis(
        option = "inferno"
      )+
      ggplot2::scale_x_continuous(
        expand = c(0, 0)
      )+
      ggplot2::scale_y_continuous(
        expand = c(0, 0)
      )+
      ggplot2::coord_cartesian(
        xlim = c(0, 1024),
        ylim = c(START_Y, END_Y)
      )+
      ggplot2::theme_classic()+
      ggplot2::labs(
        color = DIMENSION
      )-> plot_ret
    
    return(plot_ret)
    
  }
  
  
  plot_umap1 <- draw_umap(df_umap, "umap1")
  plot_umap2 <- draw_umap(df_umap, "umap2")
  
  ggplot2::ggsave(
    plot = plot_umap1, 
    filename = paste0(SaveOUT_prefix, "_PlantRegion_", START_Y, "_", END_Y, "_umap1.jpeg"),
    width = 3.5, 
    height = 4, 
    bg = "white"
  )
  
  ggplot2::ggsave(
    plot = plot_umap2, 
    filename = paste0(SaveOUT_prefix, "_PlantRegion_", START_Y, "_", END_Y, "_umap2.jpeg"),
    width = 3.5, 
    height = 4, 
    bg = "white"
  )
  
  gc()
  
  print("# select plant region by umap, and save the raw reflectance data ===================")
  print(Sys.time())
  df_plant <- df_umap %>%
    filter(
      y > 50, 
      umap1 < -5
    ) %>%
    select(
      x, y
    ) %>%
    left_join(
      x = .,
      y = df_part1, 
      by = c("x", "y")
    )
  
  gc()
  print("## Check out the selected regions ======================")
  print(Sys.time())
  plot_plant <- df_plant %>%
    ggplot2::ggplot(
      aes(
        x = x,
        y = y,
        color = `701.13`
      )
    )+
    scattermore::geom_scattermore(
      size = 0.05, na.rm = T
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
      xlim = c(0, 1024), # remember to control the x axis, otherwise the pics will be VERY strange
      ylim = c(START_Y, END_Y)
    )+
    ggplot2::theme_classic()
  
  ggplot2::ggsave(
    plot = plot_plant, 
    filename = paste0(SaveOUT_prefix, "_PlantRegion_", START_Y, "_", END_Y, ".jpeg"),
    width = 3.5, 
    height = 4, 
    bg = "white"
  )
  
  gc()
  print("## Save out the raw reflectance of selected plant regions =========================")
  data.table::fwrite(
    df_plant, 
    file = paste0(SaveOUT_prefix, "_PlantRegion_", START_Y, "_", END_Y, ".txt"),
    col.names = T, row.names = F, sep = "\t", quote = F, nThread = 4
  )
  print(Sys.time())
  
})



