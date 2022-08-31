\#\#\#Introduction Here, we explain the step-by-step analysis for the
myofiber type composition. We use a human dataset to walk you through
all the necessary step. This dataset includes muscle cryosections of 15
individuals stained with different MyHC informs (MyHC1, MyHC2A and
MyHC2X) and laminin (steps 14-30 in the STAR protocol). The samples were
imaged and image processing and quantification were done as explained in
steps 31-39 in the STAR protocol.

\#\#\#R environment setup

``` r
#Empty the R environment
rm(list = ls())
#Check if libraries are already installed, otherwise install it
if(!"rstudioapi" %in% installed.packages()) BiocManager::install("rstudioapi")
if(!"dplyr" %in% installed.packages()) install.packages("dplyr")
if(!"tidyr" %in% installed.packages()) install.packages("tidyr")
if(!"rmarkdown" %in% installed.packages())install.packages("rmarkdown") 
if(!"data.table" %in% installed.packages())install.packages("data.table")
if(!"knitr" %in% installed.packages())install.packages("knitr")
if(!"reshape2" %in% installed.packages()) install.packages("reshape2")
if(!"cowplot" %in% installed.packages()) install.packages("cowplot")
if(!"ggpubr" %in% installed.packages()) install.packages("ggpubr")
if(!"LPCM" %in% installed.packages()) install.packages("LPCM")

#Load installed libraries
suppressPackageStartupMessages({
  library(rstudioapi) #Interface for interacting with RStudio IDE with R code.
  library(dplyr)
  library(tidyr)
  library(rmarkdown)
  library(data.table)
  library(knitr)
  library(reshape2)
  library(ggplot2)
  library(cowplot)
  library(ggpubr)
  library(LPCM)
  })

#Set your working environment to the location where your current source file is saved into.
setwd(dirname(rstudioapi::getSourceEditorContext()$path))
```

\#\#\#Read all the txt files saved in step 39:

``` r
InputPath = "ROI/"
Files <- list.files(path = InputPath, pattern = "MFI.txt", full.names = T)
DataTable <- lapply(Files, read.table, as.is = T)
names(DataTable) <- gsub(":.*", "", sapply(DataTable, function(x) x[1, 1]))
```

\#\#\#Step1: Filtering based on segmentation certainty Laminin channel
was used to define 3 segmentation metrics: Mean: Laminin intensity
inside the object (The smaller the better) Mean\_boundary: Laminin
intensity on the boundary (The larger the better) StdDev\_boundary:
Standard deviation of laminin intensity on the boundary (The smaller the
better)

``` r
#Aggregated dataset for filtering
Filt1 <- rbindlist(DataTable, idcol = TRUE) %>% #importing segmentation quality data
  filter(Ch == 5) %>%
  select(.id, Label, Mean, Mean_boundary, StdDev_boundary) %>%
  unique()
#Density plot of Segmentation metrics: Before filtering
(BeforeFiltering <- ggplot(Filt1 %>% reshape2::melt(), aes_string(x = "value")) +
    geom_density(alpha = .5,) +
    theme_bw() + ggtitle("Before filtering") +
  facet_wrap(variable ~ ., scales='free', nrow = 3) +
  theme(panel.grid = element_blank (),
        legend.position = "none", axis.title = element_blank(), 
        strip.text = element_text(size = 12)))
```

![](MyofiberTyping_files/figure-markdown_github/Filt1_segmentationMetrics_denPlot-1.png)

Based on the density distribution for mean and Mean\_boundary, we filter
as below:

**Mean**: Included fibers have `Mean < 95th percentile`
**Mean\_boundary**\*: Included fibers have
`Mean_boundary > 5th percentile`

But we don’t filter for StdDev\_boundary because filtering for two other
metrics improve could it.

*Note*: One should specify these thresholds based on the input dataset.

``` r
#Percentile base filtering
Filt1_Mean <- Filt1 %>%
  filter(quantile(Mean, 0.95) > Mean) 
Filt1_Mean_boundary <- Filt1 %>%
  filter(quantile(Mean_boundary, 0.05) < Mean_boundary) 
Filt1_Mean_Mean_boundary <- merge(Filt1_Mean, Filt1_Mean_boundary)

#Add a column to show included and excluded objects
Filt_To_DataTable <- rbindlist(DataTable, idcol = TRUE) %>% 
  filter(Ch == 5) %>% 
  mutate(Included_SegQuality = ifelse(Label %in% Filt1_Mean_Mean_boundary$Label, 1, 0))

#Density plot of Segmentation metrics: After filtering
AfterFiltering <- ggplot(Filt1_Mean_Mean_boundary %>% melt(), aes_string(x = "value")) +
    geom_density(alpha = .5,) +
    theme_bw() + ggtitle("After filtering") +
  facet_wrap(variable ~ ., scales='free', nrow = 3) +
  theme(panel.grid = element_blank (),
        legend.position = "none", axis.title = element_blank(), 
        strip.text = element_text(size = 12))
plot_grid(BeforeFiltering, AfterFiltering)
```

![](MyofiberTyping_files/figure-markdown_github/Filt1_segmentationMetrics_filtering-1.png)

``` r
ggsave(plot_grid(BeforeFiltering, AfterFiltering), device = "jpeg", units = "cm", width = 12, height = 10, filename = "step1.jpeg")

rm(list = setdiff(ls(), c("DataTable", "Filt_To_DataTable"))) #Remove objects that are not required
```

\#\#\#Step2: Filtering based on CSA The next filtering step is based on
cross-sectional area (CSA). But as we apply a filtering based on the
percentile, we include all the objects (including those that are
filtered in the first step).

``` r
#Aggregated dataset for filtering
muscleAbbreviation <- c ("GAL" = "GL", "GRA" = "GR", "VAL" = "VL", "VAM" = "VM", "SED" = "STD", "SEM" = "STM", "REF" = "RF")
Filt2 <- rbindlist(DataTable, idcol = TRUE) %>% 
  filter(Ch == 4) %>%
  select(.id, Label, Area) %>%
  unique() %>%
  mutate(Area = as.numeric (Area), 
         Sample = gsub("-.*", "", .id),
         Muscle = gsub("_.*", "", gsub("^[^_]*_", "", Sample)),
         Muscle = muscleAbbreviation[match(Muscle, names(muscleAbbreviation))])
#Density plot of CSA Before filtering
(BeforeFiltering <- ggplot(Filt2 %>% filter (Area < 45000), aes_string(x = "Area")) +
    geom_density(alpha = .5,) +
    theme_bw() + ggtitle("Before filtering") +
    facet_wrap(. ~ Muscle, scales='free_y', nrow = 2) +
    theme(panel.grid = element_blank (),
          legend.position = "none", axis.title = element_blank(), 
          axis.text.x = element_text(angle = 90, vjust = 0.5), 
          strip.text = element_text(size = 12)))
```

![](MyofiberTyping_files/figure-markdown_github/Filt2_CSA_denPlot-1.png)

The CSA distribution is different across different muscles so the
filtering based on Area should be done separately for each muscle. The
aim here is to exclude small and big non-fiber objects. Since there is a
right-skewed distribution for all the muscles, we filter more from the
left side than the right.

`10th percentile < Area < 99th percentile`

``` r
for(Muscle in unique(Filt2$Muscle)) {
  MuscleFibers <- Filt2$Label [Filt2$Muscle == Muscle] 
  #Area 
  Filt2_Area <- Filt2 %>% filter(Label %in% MuscleFibers) %>%
    filter(quantile(Area, 0.10) < Area &  Area < quantile(Area, 0.99)) 
  assign (paste0("Filt2_Area_", Muscle), Filt2_Area)
}
Filt2_Area <- rbindlist(lapply(ls(pattern = "Filt2_Area_"), get))
Filt2_Area_Laminin <- Filt2_Area %>% filter(gsub(":4$", "", Label) %in% gsub(":5$", "", Filt_To_DataTable$Label [Filt_To_DataTable$Included_SegQuality == 1]))
Filt_To_DataTable <- Filt_To_DataTable %>% 
  mutate(Included_Area = ifelse(gsub(":.$", "", Label) %in% gsub(":.$", "", Filt2_Area_Laminin$Label), 1, 0))
AfterFiltering <- ggplot(Filt2_Area_Laminin, aes_string(x = "Area")) +
  geom_density(alpha = .5,) +
  theme_bw() + ggtitle("After filtering") +
  facet_wrap(. ~ Muscle, scales = 'free_y', nrow = 2) +
  theme(panel.grid = element_blank (), 
        legend.position = "none", axis.title = element_blank(), 
        axis.text.x = element_text(angle = 90, vjust = 0.5), 
        strip.text = element_text(size = 12)) 
plot_grid(BeforeFiltering, AfterFiltering, nrow = 2)
```

![](MyofiberTyping_files/figure-markdown_github/Filt2_CSA_filtering-1.png)

``` r
ggsave(plot_grid(BeforeFiltering, AfterFiltering, nrow = 2), device = "jpeg", units = "cm", width = 18, height = 15, filename = "step2.jpeg")

rm(list = setdiff(ls(), c("DataTable", "Filt_To_DataTable"))) #Remove objects that are not required
```

\#\#\#Step3: Filtering based on circularity The next filtering step is
based on circularity. The same as previous filtering, we apply a
filtering based on the percentile and we include all the objects
(including those that are filtered in the first step).

``` r
#Aggregated dataset for filtering
Filt3 <- rbindlist(DataTable, idcol = TRUE) %>% 
  filter(Ch == 4) %>%
  select(.id, Label, Circ.) %>%
  unique()
(BeforeFiltering <- ggplot(Filt3, aes_string(x = "Circ.")) +
  geom_density(alpha = .5,) +
  theme_bw() + ggtitle("Before filtering") +
  theme(panel.grid = element_blank (),
        legend.position = "none", axis.title = element_blank()))
```

![](MyofiberTyping_files/figure-markdown_github/Filt3_circularity_denPlot-1.png)

This filtering is done on all the muscles together since the circularity
distribution is the same across all the muscle.
`included fibers: Circularity > 1th percentile`

``` r
Filt3_Circularity <- Filt3 %>%
  filter(quantile(Circ., 0.01) < Circ.) 
Filt3_Circularity_Area_Laminin <- Filt3_Circularity %>% filter(gsub(":.$", "", Label) %in% gsub(":.$", "", Filt_To_DataTable$Label) [Filt_To_DataTable$Included_Area == 1])
Filt_To_DataTable <- Filt_To_DataTable %>% 
  mutate(Included_Circ = ifelse(gsub(":.$", "", Label) %in% gsub(":.$", "", Filt3_Circularity_Area_Laminin$Label), 1, 0)) %>%
  mutate(Included_SeqQAreaCirc = ifelse(Included_Circ == 1, 1, 
                                          ifelse(Included_Area == 1, 0.7, 
                                                  ifelse(Included_SegQuality == 1, 0.4, 0))))
AfterFiltering <- ggplot(Filt3_Circularity_Area_Laminin, aes_string(x = "Circ.")) +
  geom_density(alpha = .5,) +
  theme_bw() + ggtitle("After filtering") +
  theme(panel.grid = element_blank (),
        legend.position = "none", axis.title = element_blank())
  
plot_grid(BeforeFiltering, AfterFiltering)
```

![](MyofiberTyping_files/figure-markdown_github/Filt3_circularity_filtering-1.png)

``` r
ggsave(plot_grid(BeforeFiltering, AfterFiltering), device = "jpeg", units = "cm", width = 10, height = 3.3, filename = "step3.jpeg")
load("F:/Corona-WorkingFromHome/Human-Muscle-Types/OurDataset/LabWorks/4.WetLabValidation/MyofiberTyping/ImageAnalysis/FilterOutPut/AllFibers.RData")
rm(list = setdiff(ls(), c("DataTable", "Filt_To_DataTable"))) #Remove objects that are not required
```

Saving the filtering output to visualize and justify filtered objects in
ImageJ

``` r
OutputPath = "ROI/"
customFun = function(Filt_To_DataTable) {
 write.table(Filt_To_DataTable, paste0(OutputPath, unique(Filt_To_DataTable$.id), "_Filt.txt"), quote = F, sep = "\t", row.names = F)
 return(Filt_To_DataTable)
 }
Filt_To_DataTable %>% 
  tibble::rownames_to_column(var = " ") %>%
  group_by(.id) %>% 
  do(customFun(.))
```

    ## # A tibble: 369,073 x 24
    ## # Groups:   .id [293]
    ##    ` `   .id   Label  Area  Mean StdDev  Mode   Min   Max Circ. Median    Ch
    ##    <chr> <chr> <chr> <dbl> <dbl>  <dbl> <int> <int> <int> <dbl>  <int> <int>
    ##  1 1     MD11~ MD11~ 5570.  90.7  100.      0     0   255 0.596     38     5
    ##  2 2     MD11~ MD11~ 1879. 141.    86.3   255     0   255 0.773    155     5
    ##  3 3     MD11~ MD11~  811.  88.0   83.7     5     0   255 0.898     51     5
    ##  4 4     MD11~ MD11~ 2501.  69.4   87.7     0     0   255 0.535     25     5
    ##  5 5     MD11~ MD11~ 3894.  86.2   91.9     0     0   255 0.765     38     5
    ##  6 6     MD11~ MD11~ 9464.  59.8   86.1     0     0   255 0.692      7     5
    ##  7 7     MD11~ MD11~ 1291. 143.    79.6   255     0   255 0.506    153     5
    ##  8 8     MD11~ MD11~ 3427.  70.7   90.5     0     0   255 0.578     20     5
    ##  9 9     MD11~ MD11~ 6550.  45.0   80.0     0     0   255 0.812      2     5
    ## 10 10    MD11~ MD11~ 6091.  54.0   90.1     0     0   255 0.798      2     5
    ## # ... with 369,063 more rows, and 12 more variables: AR <dbl>, Round <dbl>,
    ## #   Solidity <dbl>, Mean_boundary <dbl>, StdDev_boundary <dbl>,
    ## #   Mean_distance <dbl>, Included_SegQuality <dbl>, Included_Area <dbl>,
    ## #   Included_Circ <dbl>, Included_SeqQAreaCirc <dbl>, AreaScale <dbl>,
    ## #   AreaScale01 <dbl>

``` r
rm(list = setdiff(ls(), c("DataTable", "Filt_To_DataTable"))) #Remove objects that are not required
```

Selecting one of the replicates

``` r
#Aggregated dataset
muscleAbbreviation <- c ("GAL" = "GL", "GRA" = "GR", "VAL" = "VL", "VAM" = "VM", "SED" = "STD", "SEM" = "STM", "REF" = "RF")
FiberData <- rbindlist (DataTable, idcol = TRUE) %>% 
  filter (Ch %in% c (1, 2, 3)) %>%
  select (.id, Label, Mean, Ch, Area) %>%
  unique () %>%
  mutate (Sample = gsub ("-.*", "", .id),
          Replicate = gsub (".*_", "", .id),
          Individual = gsub ("_.*", "", .id),
          Muscle = gsub ("_.*", "", gsub("^[^_]*_", "", Sample)),
          Muscle = muscleAbbreviation[match(Muscle, names(muscleAbbreviation))],
          fiber = gsub (":.$", "", Label))
#Assign each channel to corresponding isofom, based on the imaging profile
FiberData$Ch [FiberData$Ch == 1] = "MyHC1"
FiberData$Ch [FiberData$Ch == 2] = "MyHC2A"
FiberData$Ch [FiberData$Ch == 3] = "MyHC2X"
rm (list = setdiff (ls (), c ("DataTable", "Filt_To_DataTable", "FiberData")))

#Select one of the cryosections based on both number of remained myofibers after filtering and the image quality
Samples <- c ("MD11_GL_s1", "MD11_GR_s1", "MD11_STD_s2", "MD11_STM_s2", "MD11_VL_s1",
              "MD11_VM_s2", "MD13_GL_s2", "MD13_GR_s0", "MD13_RF_ s1", "MD13_STD_s2",  "MD13_STM_s2", "MD13_VL_s1", "MD13_VM_s1", "...") 
  Samples <- c ("MD11_GAL_Sam12-Batch1_2020.11.23_s1", "MD11_GRA_SecondTry_Sam74-Batch4_2020.11.26_s1", "MD11_SED_Sam71-Batch4_2020.11.26_s2", "MD11_SEM_Sam91-Batch5_2020.11.27_s2", "MD11_VAL_Sam52-Batch3_2020.11.25_s1", "MD11_VAM_Sam35-Batch2_2020.11.24_s2", "MD13_GAL_Sam2-Batch1_2020.11.23_s2", "MD13_GRA_Section3SecondTry_Sam82-Batch5_2020.11.27_s0", "MD13_REF_Sam37-Batch2_2020.11.24_s1", "MD13_SED_Sam99-Batch5_2020.11.27_s2", "MD13_SEM_Sam54-Batch3_2020.11.25_s2", "MD13_VAL_Sam25-Batch2_2020.11.24_s1", "MD13_VAM_Sam69-Batch4_2020.11.26_s1", "MD14_GAL_Sam96-Batch5_2020.11.27_s1", "MD14_GRA_Sam1-Batch1_2020.11.23_s2", "MD14_REF_Sam16-Batch1_2020.11.23_s2", "MD14_SED_Sam86-Batch5_2020.11.27_s2", "MD14_SEM_Sam31-Batch2_2020.11.24_s2", "MD14_VAL_Sam46-Batch3_2020.11.25_s1", "MD14_VAM_Sam59-Batch3_2020.11.25_s2", "MD15_GAL_Sam75-Batch4_2020.11.26_s2", "MD15_GRA_Sam13-Batch1_2020.11.23_s2", "MD15_REF_Sam44-Batch3_2020.11.25_s2", "MD15_SED_Sam7-Batch1_2020.11.23_s2", "MD15_SEM_Sam58-Batch3_2020.11.25_s1", "MD15_VAL_Sam90-Batch5_2020.11.27_s1", "MD15_VAM_Sam27-Batch2_2020.11.24_s2", "MD16_GAL_SecondTry_Sam55-Batch3_2020.11.25_s1", "MD16_GRA_Sam41-Batch3_2020.11.25_s2", "MD16_REF_Sam29-Batch2_2020.11.24_s2", "MD16_SED_Sam5-Batch1_2020.11.23_s1", "MD16_SEM_Sam73-Batch4_2020.11.26_s2", "MD16_VAL_Sam19-Batch1_2020.11.23_s1", "MD16_VAM_Sam87-Batch5_2020.11.27_s2", "MD17_GAL_Sam63-Batch4_2020.11.26_s2", "MD17_GRA_Sam88-Batch5_2020.11.27_s1", "MD17_SED_Sam22-Batch2_2020.11.24_s1", "MD17_SEM_Sam39-Batch2_2020.11.24_s2", "MD18_GAL_Sam38-Batch2_2020.11.24_s1", "MD18_GRA_Sam61-Batch4_2020.11.26_s1", "MD18_SED_Sam78-Batch4_2020.11.26_s1", "MD18_SEM_FirstTryDirty!_Sam21-Batch2_2020.11.24_s2", "MD18_VAL_Sam3-Batch1_2020.11.23_s2", "MD18_VAM_Sam50-Batch3_2020.11.25_s2", "MD19_GAL_Sam45-Batch3_2020.11.25_s0", "MD19_GRA_Sam23-Batch2_2020.11.24_s2", "MD19_REF_Sam56-Batch3_2020.11.25_s2", "MD19_SED_Sam32-Batch2_2020.11.24_s1", "MD19_SEM_Sam4-Batch1_2020.11.23_s1", "MD19_VAL_SecondTry_Sam72-Batch4_2020.11.26_s1", "MD19_VAM_Sam93-Batch5_2020.11.27_s1", "MD20_GAL_Sam26-Batch2_2020.11.24_s1",  "MD20_GRA_Sam36-Batch2_2020.11.24_s1", "MD20_REF_Sam98-Batch5_2020.11.27_s2", "MD20_SED_Sam49-Batch3_2020.11.25_s1", "MD20_SEM_Sam83-Batch5_2020.11.27_s2", "MD20_VAL_Sam67-Batch4_2020.11.26_s0", "MD20_VAM_Sam11-Batch1_2020.11.23_s2", "MD21_GAL_Sam14-Batch1_2020.11.23_s1", "MD21_GRA_Sam95-Batch5_2020.11.27_s2", "MD21_REF_Sam9-Batch1_2020.11.23_s2", "MD21_SED_Sam34-Batch2_2020.11.24_s1", "MD21_SEM_Sam42-Batch3_2020.11.25_s1", "MD21_VAL_Sam57-Batch3_2020.11.25_s2", "MD21_VAM_Sam77-Batch4_2020.11.26_s1", "MD22_GAL_Sam81-Batch5_2020.11.27_s2", "MD22_GRA_Sam68-Batch4_2020.11.26_s2", "MD22_REF_Sam51-Batch3_2020.11.25_s2", "MD22_SED_Sam92-Batch5_2020.11.27_s1", "MD22_SEM_Sam8-Batch1_2020.11.23_s2", "MD22_VAM_FirstTry_Sam24-Batch2_2020.11.24_s1", "MD26_GAL_Sam33-Batch2_2020.11.24_s0", "MD26_GRA_Sam53-Batch3_2020.11.25_s2", "MD26_REF_Sam86-Batch5_2020.11.27_s0", "MD26_SED_Sam17-Batch1_2020.11.23_s1", "MD26_SEM_SecondTry_Sam64-Batch4_2020.11.26_s2", "MD26_VAL_Sam94-Batch5_2020.11.27_s1", "MD27_GAL_Sam89-Batch5_2020.11.27_s2", "MD27_GRA_Sam10-Batch1_2020.11.23_s2", "MD27_REF_Sam66-Batch4_2020.11.26_s0", "MD27_SED_Sam43-Batch3_2020.11.25_s1", "MD27_SEM_Sam18-Batch1_2020.11.23_s2", "MD27_VAL_Sam28-Batch2_2020.11.24_s2", "MD28_GAL_Sam48-Batch3_2020.11.25_s2", "MD28_GRA_Sam30-Batch2_2020.11.24_s2", "MD28_REF_Sam79-Batch4_2020.11.26_s1", "MD28_SED_Sam62-Batch4_2020.11.26_s2", "MD28_SEM_Sam97-Batch5_2020.11.27_s2", "MD28_VAM_Sam15-Batch1_2020.11.23_s0", "MD31_GAL_Sam85-Batch5_2020.11.27_s1", "MD31_GRA_Sam40-Batch2_2020.11.24_s2", "MD31_REF_Sam70-Batch4_2020.11.26_s1", "MD31_SED_Sam65-Batch4_2020.11.26_s2", "MD31_SEM_Sam20-Batch1_2020.11.23_s2", "MD31_VAL_Sam76-Batch4_2020.11.26_s1", "MD31_VAM_Sam60-Batch3_2020.11.25_s1") 

FiberData <- FiberData %>% 
  filter (.id %in% Samples)
FiberData <- tidyr::pivot_wider (FiberData [,c ("fiber", "Individual", "Muscle", "Ch", "Mean", "Area")], names_from = Ch, values_from = Mean) 

#Dataset after the final filtering for segmentation quality, size and circularity
FiberDataFilt1_3 <- FiberData %>% 
  filter (fiber %in% gsub (":.$", "", Filt_To_DataTable$Label)[Filt_To_DataTable$Included_Circ == 1])

rm(list = setdiff(ls(), c("Filt_To_DataTable", "FiberDataFilt1_3"))) #Remove objects that are not required
```

\#\#\#Scaling and transformation

``` r
#log transformation
excl <- c("Area", "Muscle", "Individual", "fiber")
trans_Fun <- function(data, transf = "log"){
  for(i in 1:ncol(data)){
    if(!(colnames(data)[i] %in% excl)){
      data[, colnames(data)[i]] <- log(data[, colnames(data)[i]] + 1)
    }
  }
  transformed_data <- data 
  return (transformed_data)
}
FiberDataFilt1_3_transformed <- trans_Fun(FiberDataFilt1_3)

#Scaling 
FiberDataFilt1_3_scale_PImage <- FiberDataFilt1_3 %>% 
  group_by(Individual, Muscle) %>%
  mutate(MyHC2A = scale (MyHC2A, center = FALSE),
         MyHC2X = scale (MyHC2X, center = FALSE),
         MyHC1 = scale (MyHC1, center = FALSE))


FiberDataFilt1_3_scale_PImage_transformed <- trans_Fun(FiberDataFilt1_3_scale_PImage)

boxplot_MFI <- function(data, ch, step = "(Before scaling)") {
  ggplot(data, aes_string(x = "Individual", y = ch, fill = "Muscle")) + 
              geom_boxplot(alpha = 0.5) +
              scale_fill_manual(values = col.muscle) +
              theme_bw() +
              ggtitle(paste0(ch, "\n", step)) +
              theme(panel.grid = element_blank (),
                    axis.text.x = element_text(size = 12, face = "bold"),
                    axis.text.y = element_text(size = 8, face = "bold"),
                    axis.title.x = element_blank()) +
              labs(y = "MFI") 
}
values.channels <- c("MyHC1" = "#4363d8", "MyHC2A" = "#e6194B", "MyHC2X" = "#3cb44b")
col.muscle <- c("GL" = "#999999", "GR" = "#0099FF", "RF" = "#FF9999",
                "STD" = "#0033FF", "STM" = "#0066FF", "VL" = "#FF6666", 
                "VM" = "#FF3333")
ORDER <- c ("GL" = 7, "GR" = 1, "RF" = 4, "STM" = 2, "STD" = 3, "VL" = 5, "VM" = 6)

#Raw and normalized measurements (MFI)
for (ch in names(values.channels)) {
  print(boxplot_MFI(FiberDataFilt1_3_transformed, ch, "(Before scaling)"))
  print(boxplot_MFI(FiberDataFilt1_3_scale_PImage_transformed, ch, "(After scaling)"))
}
```

![](MyofiberTyping_files/figure-markdown_github/ScalingAndTransformation-1.png)![](MyofiberTyping_files/figure-markdown_github/ScalingAndTransformation-2.png)![](MyofiberTyping_files/figure-markdown_github/ScalingAndTransformation-3.png)![](MyofiberTyping_files/figure-markdown_github/ScalingAndTransformation-4.png)![](MyofiberTyping_files/figure-markdown_github/ScalingAndTransformation-5.png)![](MyofiberTyping_files/figure-markdown_github/ScalingAndTransformation-6.png)

``` r
rm(list = setdiff(ls(), c("Filt_To_DataTable", "FiberDataFilt1_3_scale_PImage_transformed"))) #Remove objects that are not required
```

\#\#\#Meanshift Clustering scaled log transformed data is the input for
the meanshift clustering

``` r
# MS_FiberFile <- ms(cbind(FiberDataFilt1_3_scale_PImage_transformed[, "MyHC1"],
#                          FiberDataFilt1_3_scale_PImage_transformed[, "MyHC2A"],
#                          FiberDataFilt1_3_scale_PImage_transformed[, "MyHC2X"]),
#                    h = 0.02, scaled = 0)
# save (MS_FiberFile, file = "MS_MyoFiber_Filt1_3.RData")
load ("F:/Corona-WorkingFromHome/Human-Muscle-Types/OurDataset/LabWorks/4.WetLabValidation/MyofiberTyping/ImageAnalysis/ClusterOutput/H0.02/MS02_MyoFiber_Filt1_3_NoScale.RData")
load ("F:/Corona-WorkingFromHome/Human-Muscle-Types/OurDataset/LabWorks/4.WetLabValidation/MyofiberTyping/ImageAnalysis/DataToCluster/FiberDataFilt1_3_scale_PImage_transformed.RData")

#Add the clustering results
#Check if the data structure did not change and add clustering results
if (all (MS_FiberFile$data[, 1] == FiberDataFilt1_3_scale_PImage_transformed$MyHC1 && 
       MS_FiberFile$data[, 2] == FiberDataFilt1_3_scale_PImage_transformed$MyHC2A &&
       MS_FiberFile$data[, 3] == FiberDataFilt1_3_scale_PImage_transformed$MyHC2X))
  FiberDataFilt1_3_scale_PImage_transformed$cluster <- as.character (MS_FiberFile$cluster.label)

#Remove very small clusters (with less than 2.2% of the myofibers)
FiberDataFilt1_3_scale_PImage_transformed <- as.data.frame (FiberDataFilt1_3_scale_PImage_transformed)
KeepClust <- names (table(FiberDataFilt1_3_scale_PImage_transformed["cluster"]))[table(FiberDataFilt1_3_scale_PImage_transformed["cluster"])/nrow(FiberDataFilt1_3_scale_PImage_transformed) > 0.022]
FiberDataFilt1_3_scale_PImage_transformed [, "cluster"] <- ifelse(FiberDataFilt1_3_scale_PImage_transformed [, "cluster"] %in% KeepClust, FiberDataFilt1_3_scale_PImage_transformed [, "cluster"], NA)

#Add MFI for different isoform for the visualization
FiltClust_To_DataTable <- Filt_To_DataTable %>% 
  mutate(fiber = gsub (":.$", "", Label)) %>%
  filter(fiber %in% FiberDataFilt1_3_scale_PImage_transformed$fiber) %>%
  mutate(MyHC1 = FiberDataFilt1_3_scale_PImage_transformed$MyHC1 [match (fiber, FiberDataFilt1_3_scale_PImage_transformed$fiber)],
         MyHC2A = FiberDataFilt1_3_scale_PImage_transformed$MyHC2A [match (fiber, FiberDataFilt1_3_scale_PImage_transformed$fiber)],
         MyHC2X = FiberDataFilt1_3_scale_PImage_transformed$MyHC2X [match (fiber, FiberDataFilt1_3_scale_PImage_transformed$fiber)],
         cluster = as.numeric (as.factor (FiberDataFilt1_3_scale_PImage_transformed$cluster [match (fiber, FiberDataFilt1_3_scale_PImage_transformed$fiber)])),
         Sample = gsub ("-.*", "", .id),
         Replicate = gsub (".*_", "", .id),
         Individual = gsub ("_.*", "", .id),
         Muscle = gsub ("_.*", "", gsub("^[^_]*_", "", Sample)),
         cluster = gsub("Cluster NA", "SmallCluters", paste("Cluster", cluster)))
rm(list = setdiff(ls(), c("FiltClust_To_DataTable"))) #Remove objects that are not required
```

\#\#\#Visualization and interpretation of the myofiber clustering
results

``` r
col.isoform <- c ("MyHC1" = "#0066CC", "MyHC2A" = "#CC3333", "MyHC2X" = "#339966")
FiltClust_To_DataTable %>% 
  dplyr::filter(!cluster %in% c("SmallCluters")) %>% 
  dplyr::select(fiber, Individual, Muscle, cluster, MyHC1, MyHC2A, MyHC2X) %>%
  gather (key = Isoform, value = Value, MyHC1, MyHC2A, MyHC2X) %>% 
  na.omit () %>% 
  mutate (Isoform = gsub ("_.*", "", Isoform)) %>%
  ggplot (aes (x = cluster, y = Value, fill = Isoform)) +
  geom_boxplot (alpha = 0.5) + scale_fill_manual (values = col.isoform) +
  theme_bw () + theme (panel.grid = element_blank (), 
                       axis.title.x = element_blank()) + labs (y = "scaled transformed MFI")
```

![](MyofiberTyping_files/figure-markdown_github/VisualizationAndInterpretation-1.png)

``` r
col.cluster <- c ("Cluster 2" = "#0066CC", "Cluster 1" = "#CC3333", "Cluster 3" = "#339966")

P1 <- ggscatterhist(FiltClust_To_DataTable %>% dplyr::filter(!cluster %in% c("SmallCluters")), 
                    x = "MyHC1", y = "MyHC2A", color = "cluster", size = 2, 
                    alpha = 0.01, palette = col.cluster, xlab = "MFI for MyHC1" , ylab = "MFI for MyHC2A",
                    margin.params = list(fill = "cluster", color = "black", size = 0.3),
                    margin.plot = "boxplot", legend = "none")
```

![](MyofiberTyping_files/figure-markdown_github/VisualizationAndInterpretation-2.png)

``` r
ggexport(P1, filename = "Clustering1-2A.jpeg", res = 200, height = 800, width = 800)
P2 <- ggscatterhist(FiltClust_To_DataTable %>% dplyr::filter(!cluster %in% c("SmallCluters")),
                    x = "MyHC1", y = "MyHC2X", color = "cluster", size = 2, 
                    alpha = 0.01, palette = col.cluster, xlab = "MFI for MyHC1" , ylab = "MFI for MyHC2X",
                    margin.params = list(fill = "cluster", color = "black", size = 0.3),
                    margin.plot = "boxplot", legend = "none")
```

![](MyofiberTyping_files/figure-markdown_github/VisualizationAndInterpretation-3.png)

``` r
ggexport(P2, filename = "Clustering1-2X.jpeg", res = 200, height = 800, width = 800)
P3 <- ggscatterhist(FiltClust_To_DataTable %>% dplyr::filter(!cluster %in% c("SmallCluters")),
                    x = "MyHC2A", y = "MyHC2X", color = "cluster", size = 2, 
                    alpha = 0.01, palette = col.cluster, xlab = "MFI for MyHC2A" , ylab = "MFI for MyHC2X",
                    margin.params = list(fill = "cluster", color = "black", size = 0.3),
                    margin.plot = "boxplot", legend = "none")
```

![](MyofiberTyping_files/figure-markdown_github/VisualizationAndInterpretation-4.png)

``` r
ggexport(P3, filename = "Clustering2A-2X.jpeg", res = 200, height = 800, width = 800)

#Myofiber type composition across different sample groups
ORDER <- c ("GL" = 7, "GR" = 1, "RF" = 4, "STM" = 2, "STD" = 3, "VL" = 5, "VM" = 6)
muscleAbbreviation <- c ("GAL" = "GL", "GRA" = "GR", "VAL" = "VL", "VAM" = "VM", "SED" = "STD", "SEM" = "STM", "REF" = "RF")
col.muscle <- c("GL" = "#999999", "GR" = "#0099FF", "RF" = "#FF9999",
                "STD" = "#0033FF", "STM" = "#0066FF", "VL" = "#FF6666", 
                "VM" = "#FF3333")
(Tosave <- FiltClust_To_DataTable %>% dplyr::filter(!cluster %in% c("SmallCluters")) %>%
  mutate (order = ORDER[match (Muscle, names (ORDER))],
          Muscle = muscleAbbreviation [match (Muscle, names (muscleAbbreviation))]) %>%
  group_by (Individual, Muscle, Sample, order) %>%
  count (cluster) %>%
  group_by (Individual, Muscle, Sample, order) %>%
  mutate (per.n = (n / (sum (n)) * 100 )) %>%
  ggplot (aes (x = cluster, y = per.n, fill = forcats::fct_reorder (Muscle, order))) +
  geom_boxplot (alpha = 0.5) +
  scale_fill_manual (values = col.muscle) +
  theme_bw () + labs(fill = "Muscle", y = "%Myofibers") +
  theme (panel.grid = element_blank (), 
         axis.text.x = element_text (size = 10), 
         axis.text.y = element_text (size = 10),
         axis.ticks = element_blank (), legend.text = element_text (size = 10, vjust = 0.5), axis.title.y = element_text (size = 10), axis.title.x = element_blank()))
```

![](MyofiberTyping_files/figure-markdown_github/VisualizationAndInterpretation-5.png)

``` r
ggsave(Tosave, device = "jpeg", units = "cm", width = 12, height = 10, filename = "Per_MyofiberInClusters.jpeg")
rm(list = ls())
```

\#\#\#Printing session info

``` r
sessionInfo ()
```

    ## R version 4.0.2 (2020-06-22)
    ## Platform: x86_64-w64-mingw32/x64 (64-bit)
    ## Running under: Windows 10 x64 (build 19043)
    ## 
    ## Matrix products: default
    ## 
    ## locale:
    ## [1] LC_COLLATE=English_United Kingdom.1252 
    ## [2] LC_CTYPE=English_United Kingdom.1252   
    ## [3] LC_MONETARY=English_United Kingdom.1252
    ## [4] LC_NUMERIC=C                           
    ## [5] LC_TIME=English_United Kingdom.1252    
    ## 
    ## attached base packages:
    ## [1] stats     graphics  grDevices utils     datasets  methods   base     
    ## 
    ## other attached packages:
    ##  [1] LPCM_0.46-7       ggpubr_0.4.0      cowplot_1.0.0     ggplot2_3.3.2    
    ##  [5] reshape2_1.4.4    knitr_1.29        data.table_1.12.8 rmarkdown_2.5    
    ##  [9] tidyr_1.1.0       dplyr_1.0.0       rstudioapi_0.11  
    ## 
    ## loaded via a namespace (and not attached):
    ##  [1] tidyselect_1.1.0 xfun_0.15        purrr_0.3.4      haven_2.3.1     
    ##  [5] carData_3.0-4    colorspace_1.4-1 vctrs_0.3.1      generics_0.0.2  
    ##  [9] htmltools_0.5.0  yaml_2.2.1       utf8_1.1.4       rlang_0.4.6     
    ## [13] pillar_1.4.6     foreign_0.8-80   glue_1.4.1       withr_2.3.0     
    ## [17] readxl_1.3.1     lifecycle_0.2.0  plyr_1.8.6       stringr_1.4.0   
    ## [21] munsell_0.5.0    ggsignif_0.6.0   gtable_0.3.0     cellranger_1.1.0
    ## [25] zip_2.1.0        evaluate_0.14    labeling_0.4.2   rio_0.5.16      
    ## [29] forcats_0.5.0    curl_4.3         fansi_0.4.1      broom_0.7.2     
    ## [33] Rcpp_1.0.4.6     scales_1.1.1     backports_1.1.7  abind_1.4-7     
    ## [37] farver_2.0.3     hms_0.5.3        digest_0.6.25    stringi_1.4.6   
    ## [41] openxlsx_4.1.5   rstatix_0.6.0    grid_4.0.2       cli_2.1.0       
    ## [45] tools_4.0.2      magrittr_2.0.1   tibble_3.0.1     crayon_1.3.4    
    ## [49] car_3.0-10       pkgconfig_2.0.3  ellipsis_0.3.1   assertthat_0.2.1
    ## [53] R6_2.5.0         compiler_4.0.2
