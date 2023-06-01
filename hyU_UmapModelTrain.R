#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)
# AIM: extract the XY location and reflectance by R

# test if there is at least one argument: if not, return an error
if (length(args)!=2) {
  stop("Usage: hyU_UmapModelTrain.R <tsv table from hyspec_ENVItoTable.R> <output_prefix>", call.=FALSE)
}

# define output name-------------------
SaveOUT_prefix <- as.character(x = args[2])
CORE <- as.numeric(8)

# library ----------------------------
library(cowplot)
library(viridis)
library(RColorBrewer)
library(data.table)
library(tidyverse)
library(uwot)

setDTthreads(threads = CORE)

print("# read whole data, it takes long time ====================================")
Sys.time()
df <- fread(args[1], header = T, sep = "\t", nThread = CORE)
Sys.time()

print("# Choose part of image, it can reduce I/O time ========================")
Sys.time()
df_part1 <- df[y<1000 & y>50,]
Sys.time()

print("# Normalized =========================")
Sys.time()
df_part1_melt <- df_part1 %>%
  data.table::melt.data.table(
    id.vars = c("x", "y")
  ) 
Sys.time()  

df_part1_norm <- df_part1_melt[,.(variable, normal = ( value - min(value))/(max(value) - min(value))), by = .(x, y)]
Sys.time()

rm(df_part1_melt)

Sys.time()
df_part1_dcast <- data.table::dcast.data.table(
  x + y ~ variable, data = df_part1_norm, value.var = "normal", fill = 0
)
Sys.time()

rm(df_part1_norm)

print("# uwot, need ~30 min, more thread is NOT faster!! ====================================")
Sys.time()
set.seed(1459)
model_df_part1_dcast <- uwot::umap(
  X = df_part1_dcast[,3:dim(df_part1_dcast)[2]],
  n_neighbors = 15,
  n_components = 2,
  metric = "euclidean",
  n_epochs = 200,
  scale = F,
  init = "spectral",
  min_dist = 0.1,
  set_op_mix_ratio = 1,
  local_connectivity = 1,
  bandwidth = 1,
  negative_sample_rate = 5,
  spread = 1,
  learning_rate = 1,
  search_k = 4,
  n_threads = CORE,  # change this CPU thread
  approx_pow = F,
  verbose = T,
  ret_model = T,
  ret_nn = T
)

Sys.time()
gc()

print("# Save model, only use ONE TIME !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! ")
Sys.time()
uwot::save_uwot(
  model_df_part1_dcast, 
  file = paste0("uwot_model_from_", SaveOUT_prefix) #"/nas/nas7/project2/Brassica_diversity/TEST_hyper/uwot_model_1415RT_part1", 
  )
Sys.time()

# print("# reuse the model for other parts/pics ============================================")
# 
# model_df_part1_dcast <- uwot::load_uwot(
#   file = paste0("uwot_model_from_", SaveOUT_prefix), #"/nas/nas7/project2/Brassica_diversity/TEST_hyper/uwot_model_1415RT_part1", 
#   verbose = T
# )

print("# Visulize the umap result ========================================")
Sys.time()
df_umap <- cbind(df_part1_dcast[,1:2], model_df_part1_dcast$embedding)

colnames(df_umap) <- c("x", "y", "umap1", "umap2")

# Define drawing function ----------------
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
      xlim = c(0, NA),
      ylim = c(0, NA)
    )+
    ggplot2::theme_classic()+
    ggplot2::labs(
      color = DIMENSION
    )-> plot_ret
  
  return(plot_ret)
  
}

# draw and save -----------------
Sys.time()
plot_umap1 <- draw_umap(df_umap, "umap1")
Sys.time()
plot_umap2<- draw_umap(df_umap, "umap2")

Sys.time()
cowplot::ggsave2(
  plot = plot_umap1, 
  filename = paste0(SaveOUT_prefix, "_umap1.jpeg"), #"/nas/nas7/project2/Brassica_diversity/TEST_hyper/TEST.1415RT_umap1.jpeg", 
  width = 3.5, 
  height = 4,
  bg = "white"
)

Sys.time()
cowplot::ggsave2(
  plot = plot_umap2, 
  filename = paste0(SaveOUT_prefix, "_umap2.jpeg"), #"/nas/nas7/project2/Brassica_diversity/TEST_hyper/TEST.1415RT_umap2.jpeg", 
  width = 3.5, 
  height = 4,
  bg = "white"
)
Sys.time()

print("# save umap data frame for further selection, or delete it =====================")
Sys.time()
data.table::fwrite(
  df_umap, 
  file = paste0(SaveOUT_prefix, "_umap.txt"), #"/nas/nas7/project2/Brassica_diversity/TEST_hyper/TEST.1415RT_umap.txt", 
  col.names = T, row.names = F, sep = "\t", nThread = CORE, quote = F
)
Sys.time()

print("# select plant region by umap, and save the raw reflectance data ===================")
Sys.time()
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
  
print("## Check out the selected regions ======================")
Sys.time()
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
    ylim = c(0, NA)
  )+
  ggplot2::theme_classic()

Sys.time()
ggplot2::ggsave(
  plot = plot_plant, 
  filename = paste0(SaveOUT_prefix, "_PlantRegion.jpeg"), #"/nas/nas7/project2/Brassica_diversity/TEST_hyper/TEST.1415RT_PlantRegion.jpeg",
  width = 3.5, 
  height = 4, 
  bg = "white"
)

print("## Save out the raw reflectance of selected plant regions =========================")
Sys.time()
data.table::fwrite(
  df_plant, 
  file = paste0(SaveOUT_prefix, "_PlantRegion.txt"), #"/nas/nas7/project2/Brassica_diversity/TEST_hyper/TEST.1415RT_PlantRegion.txt", 
  col.names = T, row.names = F, sep = "\t", quote = F, nThread = CORE
)
Sys.time()
