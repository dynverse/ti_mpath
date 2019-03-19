#!/usr/local/bin/Rscript

task <- dyncli::main()

library(jsonlite)
library(readr)
library(dplyr)
library(purrr)

library(Mpath)

#   ____________________________________________________________________________
#   Load data                                                               ####

counts <- as.matrix(task$counts)
parameters <- task$parameters
groups_id <- task$priors$groups_id

#   ____________________________________________________________________________
#   Run method                                                              ####

if (parameters$numcluster_null) {
  numcluster <- NULL
}

# TIMING: done with preproc
checkpoints <- list(method_afterpreproc = as.numeric(Sys.time()))

# collect sample info
sample_info <- groups_id %>% select(cell_id, GroupID = group_id) %>% as.data.frame

# designate landmarks
landmark_cluster <- Mpath::landmark_designation(
  rpkmFile = t(counts),
  baseName = NULL,
  sampleFile = sample_info,
  distMethod = parameters$distMethod,
  method = parameters$method,
  numcluster = min(parameters$numcluster, nrow(counts) - 1),
  diversity_cut = parameters$diversity_cut,
  size_cut = parameters$size_cut,
  saveRes = FALSE
) %>%
  mutate_if(is.factor, as.character)

milestone_ids <- unique(landmark_cluster$landmark_cluster)

# catch situation where mpath only detects 1 landmark
if (length(milestone_ids) == 1) {
  warning("Mpath only detected one landmark")

  milestone_network <-
    data_frame(
      from = "M1",
      to = "M1",
      length = 0,
      directed = FALSE
    )
} else {
  # build network
  network <- Mpath::build_network(
    exprs = t(counts),
    baseName = NULL,
    landmark_cluster = landmark_cluster,
    distMethod = parameters$distMethod,
    writeRes = FALSE
  )

  # trim network
  trimmed_network <- Mpath::trim_net(
    nb12 = network,
    writeRes = FALSE
  )

  # create final milestone network
  class(trimmed_network) <- NULL
  milestone_network <- trimmed_network %>%
    reshape2::melt(varnames = c("from", "to"), value.name = "length") %>%
    mutate_if(is.factor, as.character) %>%
    filter(length > 0, from < to) %>%
    mutate(directed = FALSE)
}

# TIMING: done with method
checkpoints$method_aftermethod <- as.numeric(Sys.time())

grouping <-
  tibble::deframe(landmark_cluster)

output <- lst(
  cell_ids = names(grouping),
  grouping,
  milestone_network,
  timings = checkpoints
)

#   ____________________________________________________________________________
#   Save output                                                             ####

output <- dynwrap::wrap_data(cell_ids = names(grouping)) %>%
  dynwrap::add_cluster_graph(
    milestone_network = milestone_network,
    grouping = grouping
  ) %>%
  dynwrap::add_timings(checkpoints)

dyncli::write_output(output, task$output)
