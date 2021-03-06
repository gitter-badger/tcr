########## Data processing functions ##########


#' Parse input table files with the immune receptor repertoire data.
#'
#' @description
#' General parser for cloneset table files. Each column name has specific purpose (e.g., column for
#' CDR3 nucleotide sequence or aligned gene segments), so you need to supply column names which has this
#' purpose in your input data.
#'
#' @param .filename Path to the input file with cloneset data.
#' @param .nuc.seq Name of the column with CDR3 nucleotide sequences.
#' @param .aa.seq Name of the column with CDR3 amino acid sequences.
#' @param .reads Name of the column with counts of reads for each clonotype.
#' @param .barcodes Name of the column with counts of barcodes (UMI, events) for each clonotype.
#' @param .vgenes Name of the column with names of aligned Variable gene segments.
#' @param .jgenes Name of the column with names of aligned Joining gene segments.
#' @param .dgenes Name of the column with names of aligned Diversity gene segments.
#' @param .vend Name of the column with last positions of aligned V gene segments.
#' @param .jstart Name of the column with first positions of aligned J gene segments.
#' @param .dalignments Character vector of length two that names columns with D5' and D3' end positions.
#' @param .vd.insertions Name of the column with VD insertions for each clonotype.
#' @param .dj.insertions Name of the column with DJ insertions for each clonotype.
#' @param .total.insertions Name of the column with total number of insertions for each clonotype.
#' @param .skip How many lines from beginning to skip.
#' @param .sep Separator character.
#' 
#' @return Data frame with immune receptor repertoire data. See \link{parse.file} for more details.
#' 
#' @seealso \link{parse.file}
#' 
#' @examples
#' \dontrun{
#' # Parse file in "~/mitcr/immdata1.txt" as a MiTCR file.
#' immdata1 <- parse.file("~/mitcr/immdata1.txt", 'mitcr')
#' }
parse.cloneset <- function (.filename,
                            .nuc.seq,
                            .aa.seq,
                            .reads,
                            .barcodes,
                            .vgenes,
                            .jgenes,
                            .dgenes,
                            .vend,
                            .jstart,
                            .dalignments,
                            .vd.insertions,
                            .dj.insertions,
                            .total.insertions,
                            .skip = 0,
                            .sep = '\t') {
  
  .make.names <- function (.char) {
    if (is.na(.char[1])) { NA }
    else { make.names(.char) }
  }
  
  .nuc.seq <- .make.names(.nuc.seq)
  .aa.seq <- .make.names(.aa.seq)
  .reads <- .make.names(.reads)
  .barcodes <- .make.names(.barcodes)
  .vgenes <- .make.names(.vgenes)
  .jgenes <- .make.names(.jgenes)
  .dgenes <- .make.names(.dgenes)
  .vend <- .make.names(.vend)
  .jstart <- .make.names(.jstart)
  .vd.insertions <- .make.names(.vd.insertions)
  .dj.insertions <- .make.names(.dj.insertions)
  .total.insertions <- .make.names(.total.insertions)
  .dalignments1 <- .make.names(.dalignments[1])
  .dalignments2 <- .make.names(.dalignments[2])
  .dalignments <- .make.names(.dalignments)
  
  table.colnames <- make.names(read.table(gzfile(.filename), sep = .sep, skip = .skip, nrows = 1, stringsAsFactors = F, strip.white = T, comment.char = "")[1,])
  
  swlist <- list('character', 'character',
                 'integer', 'integer',
                 'character', 'character', 'character',
                 'integer', 'integer', 'integer', 'integer',
                 'integer', 'integer', 'integer')
  names(swlist) <- c(.nuc.seq, .aa.seq,
                     .reads, .barcodes,
                     .vgenes, .jgenes, .dgenes,
                     .vend, .jstart, .dalignments,
                     .vd.insertions, .dj.insertions, .total.insertions)
  swlist <- c(swlist, 'NULL')
  
  col.classes <- unlist(sapply(table.colnames, function (x) {
    do.call(switch, c(x, swlist))
  }, USE.NAMES = F))
  
  suppressWarnings(df <- read.table(file = gzfile(.filename), header = T, colClasses = col.classes, sep = .sep, skip = .skip, strip.white = T, comment.char = ""))
  
  df$Read.proportion <- df[, make.names(.reads)] / sum(df[, make.names(.reads)])
  .read.prop <- 'Read.proportion'
  
  if(is.na(.barcodes)) {
    .barcodes <- "Umi.count"
    df$Umi.count <- NA
    df$Umi.proportion <- NA
  } else {
    df$Umi.proportion <- df[, make.names(.barcodes)] / sum(df[, make.names(.barcodes)])
  }
  .umi.prop <- 'Umi.proportion'
  
  if (is.na(.aa.seq)) {
    df$CDR3.amino.acid.sequence <- bunch.translate(df$CDR3.nucleotide.sequence)
    .aa.seq <- 'CDR3.amino.acid.sequence'
  }
  
  # check for VJ or VDJ recombination
  # VJ / VDJ / Undeterm
  recomb_type = "Undeterm"
  if (sum(substr(head(df)[[.vgenes]], 1, 4) %in% c("TCRA", "TRAV", "TRGV", "IGKV", "IGLV"))) {
    recomb_type = "VJ"
  } else if (sum(substr(head(df)[[.vgenes]], 1, 4) %in% c("TCRB", "TRBV", "TRDV", "IGHV"))) {
    recomb_type = "VDJ"
  }
  
  if (!(.vd.insertions %in% table.colnames)) { 
    .vd.insertions <- "VD.insertions"
    if (recomb_type == "VJ") {
      df$VD.insertions <- -1
    } else if (recomb_type == "VDJ") {
      df$VD.insertions <- df[[.dalignments1]] - df[[.vend]] - 1
      df$VD.insertions[df[[.dalignments1]] == -1] <- -1
      df$VD.insertions[df[[.vend]] == -1] <- -1
    } else {
      df$VD.insertions <- -1
    }
  }
  
  if (!(.dj.insertions %in% table.colnames)) { 
    .dj.insertions <- "DJ.insertions"
    if (recomb_type == "VJ") {
      df$DJ.insertions <- -1
    } else if (recomb_type == "VDJ") {
      df$DJ.insertions <- df[[.jstart]] - df[[.dalignments2]] - 1
      df$DJ.insertions[df[[.dalignments2]] == -1] <- -1
      df$DJ.insertions[df[[.jstart]] == -1] <- -1
    } else {
      df$DJ.insertions <- -1
    }
  }
  
  if (!(.total.insertions %in% table.colnames)) {
    .total.insertions <- "Total.insertions"
    if (recomb_type == "VJ") {
      df$Total.insertions <- df[[.jstart]] - df[[.vend]] - 1
      df$Total.insertions[df[[.vend]] == -1] <- -1
      df$Total.insertions[df[[.jstart]] == -1] <- -1
    } else if (recomb_type == "VDJ" ) {
      df$Total.insertions <- df[[.vd.insertions]] + df[[.dj.insertions]]
    } else {
      df$Total.insertions <- -1
    }
  }
  
  df <- df[, make.names(c(.barcodes, .umi.prop, .reads, .read.prop, 
                          .nuc.seq, .aa.seq,
                          .vgenes, .jgenes, .dgenes,
                          .vend, .jstart, .dalignments,
                          .vd.insertions, .dj.insertions, .total.insertions))]
  
  
  colnames(df) <- c('Umi.count', 'Umi.proportion', 'Read.count', 'Read.proportion',
                    'CDR3.nucleotide.sequence', 'CDR3.amino.acid.sequence',
                    'V.gene', 'J.gene', 'D.gene',
                    'V.end', 'J.start', 'D5.end', 'D3.end',
                    'VD.insertions', 'DJ.insertions', 'Total.insertions')
  
  df
}


#' Parse input table files with immune receptor repertoire data.
#'
#' @aliases parse.folder parse.file.list parse.file parse.mitcr parse.mitcrbc parse.migec parse.vdjtools parse.immunoseq
#'
#' @description
#' Load the TCR data from the file with the given filename
#' to a data frame. For a general parser see \code{\link{parse.cloneset}}. Parsers are available for:
#' MiTCR ("mitcr"), MiTCR w/ UMIs ("mitcrbc"), MiGEC ("migec"), VDJtools ("vdjtools"), ImmunoSEQ ("immunoseq").
#' Input files could also be archived with gzip ("filename.txt.gz") or bzip2 ("filename.txt.bz2").
#' 
#' @usage
#' parse.file(.filename, 
#' .format = c('mitcr', 'mitcrbc', 'migec', 'vdjtools', 'immunoseq'), ...)
#' 
#' parse.file.list(.filenames, 
#' .format = c('mitcr', 'mitcrbc', 'migec', 'vdjtools', 'immunoseq'), .namelist = NA)
#' 
#' parse.folder(.folderpath, 
#' .format = c('mitcr', 'mitcrbc', 'migec', 'vdjtools', 'immunoseq'), ...)
#' 
#' parse.mitcr(.filename)
#' 
#' parse.mitcrbc(.filename)
#' 
#' parse.migec(.filename)
#' 
#' parse.vdjtools(.filename)
#' 
#' parse.immunoseq(.filename)
#'
#' @param .filename Path to the input file with cloneset data.
#' @param .filenames Vector or list with paths to files with cloneset data.
#' @param .folderpath Path to the folder with text cloneset files.
#' @param .format String specifing input format of files.
#' @param .namelist Either NA or character vector of length \code{.filenames} with names for output data frames.
#' @param ... Parameters passed to \code{parse.cloneset}.
#' 
#' @return Data frame with immune receptor repertoire data. Each row in this data frame corresponds to a clonotype.
#' The data frame has following columns:
#' 
#' - "Umi.count" - number of barcodes (events, UMIs);
#' 
#' - "Umi.proportion" - proportion of barcodes (events, UMIs);
#' 
#' - "Read.count" - number of reads;
#' 
#' - "Read.proportion" - proportion of reads;
#' 
#' - "CDR3.nucleotide.sequence" - CDR3 nucleotide sequence;
#' 
#' - "CDR3.amino.acid.sequence" - CDR3 amino acid sequence;
#' 
#' - "V.gene" - names of aligned Variable gene segments;
#' 
#' - "J.gene" - names of aligned Joining gene segments;
#' 
#' - "D.gene" - names of aligned Diversity gene segments;
#' 
#' - "V.end" - last positions of aligned V gene segments (1-based);
#' 
#' - "J.start" - first positions of aligned J gene segments (1-based);
#' 
#' - "D5.end" - positions of D'5 end of aligned D gene segments (1-based);
#' 
#' - "D3.end" - positions of D'3 end of aligned D gene segments (1-based);
#' 
#' - "VD.insertions" - number of inserted nucleotides (N-nucleotides) at V-D junction (-1 for receptors with VJ recombination);
#' 
#' - "DJ.insertions" - number of inserted nucleotides (N-nucleotides) at D-J junction (-1 for receptors with VJ recombination);
#' 
#' - "Total.insertions" - total number of inserted nucleotides (number of N-nucleotides at V-J junction for receptors with VJ recombination).
#' 
#' @seealso \link{parse.cloneset}
#' 
#' @examples
#' \dontrun{
#' # Parse file in "~/mitcr/immdata1.txt" as a MiTCR file.
#' immdata1 <- parse.file("~/mitcr/immdata1.txt", 'mitcr')
#' # Parse VDJtools file archive as .gz file.
#' immdata1 <- parse.file("~/mitcr/immdata3.txt.gz", 'vdjtools')
#' # Parse files "~/data/immdata1.txt" and "~/data/immdat2.txt" as MiGEC files.
#' immdata12 <- parse.file.list(c("~/data/immdata1.txt",
#'                              "~/data/immdata2.txt"), 'migec')
#' # Parse all files in "~/data/" as MiGEC files.
#' immdata <- parse.folder("~/data/", 'migec')
#' }
parse.folder <- function (.folderpath, .format = c('mitcr', 'mitcrbc', 'migec', 'vdjtools', 'immunoseq'), ...) {
  parse.file.list(list.files(.folderpath, full.names = T), .format)
}

parse.file.list <- function (.filenames, .format = c('mitcr', 'mitcrbc', 'migec', 'vdjtools', 'immunoseq'), .namelist = NA) {
  # Remove full paths and extension from the given string.
  .remove.ext <- function (.str) {
    gsub(pattern = '.*/|[.].*$', replacement = '', x = .str)
    #     .str
  }
  
  .filenames <- as.list(.filenames)
  
  datalist <- lapply(X = 1:length(.filenames), FUN = function (i) parse.file(.filenames[[i]], .format) )
  if (is.na(.namelist)) {
    namelist <- lapply(X = .filenames, FUN = .remove.ext)
    names(datalist) <- unlist(namelist)
  }
  datalist
}

parse.file <- function(.filename, .format = c('mitcr', 'mitcrbc', 'migec', 'vdjtools', 'immunoseq'), ...) {
  
  parse.fun <- switch(.format[1], 
                      mitcr = parse.mitcr,
                      mitcrbc = parse.mitcrbc,
                      migec = parse.migec,
                      vdjtools = parse.vdjtools,
                      parse.cloneset)
  
  parse.fun(.filename, ...)
}

parse.mitcr <- function (.filename) {
  filename <- .filename
  nuc.seq <- 'CDR3 nucleotide sequence'
  aa.seq <- 'CDR3 amino acid sequence'
  reads <- 'Read count'
  barcodes <- NA
  vgenes <- 'V segments'
  jgenes <- 'J segments'
  dgenes <- 'D segments'
  vend <- 'Last V nucleotide position'
  jstart <- 'First J nucleotide position'
  dalignments <- c('First D nucleotide position', 'Last D nucleotide position')
  vd.insertions <- 'VD insertions'
  dj.insertions <- 'DJ insertions'
  total.insertions <- 'Total insertions'
  .skip = 1
  .sep = '\t'
    
  parse.cloneset(.filename = filename, 
                 .nuc.seq = nuc.seq,
                 .aa.seq = aa.seq,
                 .reads = reads,
                 .barcodes = barcodes,
                 .vgenes = vgenes,
                 .jgenes = jgenes,
                 .dgenes = dgenes,
                 .vend = vend,
                 .jstart = jstart,
                 .dalignments = dalignments,
                 .vd.insertions = vd.insertions,
                 .dj.insertions = dj.insertions,
                 .total.insertions = total.insertions,
                 .skip = .skip,
                 .sep = .sep)
}

parse.mitcrbc <- function (.filename) {
  filename <- .filename
  nuc.seq <- 'CDR3 nucleotide sequence'
  aa.seq <- 'CDR3 amino acid sequence'
  reads <- 'Count'
  barcodes <- 'NNNs'
  vgenes <- 'V segments'
  jgenes <- 'J segments'
  dgenes <- 'D segments'
  vend <- 'Last V nucleotide position'
  jstart <- 'First J nucleotide position'
  dalignments <- c('First D nucleotide position', 'Last D nucleotide position')
  vd.insertions <- 'VD insertions'
  dj.insertions <- 'DJ insertions'
  total.insertions <- 'Total insertions'
  .skip = 0
  .sep = '\t'
  
  parse.cloneset(.filename = filename, 
                 .nuc.seq = nuc.seq,
                 .aa.seq = aa.seq,
                 .reads = reads,
                 .barcodes = barcodes,
                 .vgenes = vgenes,
                 .jgenes = jgenes,
                 .dgenes = dgenes,
                 .vend = vend,
                 .jstart = jstart,
                 .dalignments = dalignments,
                 .vd.insertions = vd.insertions,
                 .dj.insertions = dj.insertions,
                 .total.insertions = total.insertions,
                 .skip = .skip,
                 .sep = .sep)
}

parse.migec <- function (.filename) {
  filename <- .filename
  nuc.seq <- 'CDR3 nucleotide sequence'
  aa.seq <- 'CDR3 amino acid sequence'
  reads <- 'Good reads'
  barcodes <- 'Good events'
  vgenes <- 'V segments'
  jgenes <- 'J segments'
  dgenes <- 'D segments'
  vend <- 'Last V nucleotide position'
  jstart <- 'First J nucleotide position'
  dalignments <- c('First D nucleotide position', 'Last D nucleotide position')
  vd.insertions <- 'VD insertions'
  dj.insertions <- 'DJ insertions'
  total.insertions <- 'Total insertions'
  .skip = 0
  .sep = '\t'
  
  parse.cloneset(.filename = filename, 
                 .nuc.seq = nuc.seq,
                 .aa.seq = aa.seq,
                 .reads = reads,
                 .barcodes = barcodes,
                 .vgenes = vgenes,
                 .jgenes = jgenes,
                 .dgenes = dgenes,
                 .vend = vend,
                 .jstart = jstart,
                 .dalignments = dalignments,
                 .vd.insertions = vd.insertions,
                 .dj.insertions = dj.insertions,
                 .total.insertions = total.insertions,
                 .skip = .skip,
                 .sep = .sep)
}

parse.vdjtools <- function (.filename) {
  filename <- .filename
  nuc.seq <- 'cdr3nt'
  aa.seq <- 'cdr3aa'
  reads <- '#count'
  barcodes <- '#count'
  vgenes <- 'v'
  jgenes <- 'j'
  dgenes <- 'd'
  vend <- 'VEnd'
  jstart <- 'JStart'
  dalignments <- c('DStart', 'DEnd')
  vd.insertions <- "NO SUCH COLUMN AT ALL 1"
  dj.insertions <- "NO SUCH COLUMN AT ALL 2"
  total.insertions <- "NO SUCH COLUMN AT ALL 3"
  .skip = 0
  .sep = '\t'
  
  parse.cloneset(.filename = filename, 
                 .nuc.seq = nuc.seq,
                 .aa.seq = aa.seq,
                 .reads = reads,
                 .barcodes = barcodes,
                 .vgenes = vgenes,
                 .jgenes = jgenes,
                 .dgenes = dgenes,
                 .vend = vend,
                 .jstart = jstart,
                 .dalignments = dalignments,
                 .vd.insertions = vd.insertions,
                 .dj.insertions = dj.insertions,
                 .total.insertions = total.insertions,
                 .skip = .skip,
                 .sep = .sep)
}

parse.immunoseq <- function (.filename) {
  filename <- .filename
  nuc.seq <- 'nucleotide'
  aa.seq <- 'aminoAcid'
  reads <- 'count'
  barcodes <- 'vIndex'
  vgenes <- 'vGeneName'
  jgenes <- 'jGeneName'
  dgenes <- 'dFamilyName'
  vend <- 'n1Index'
  jstart <- 'jIndex'
  dalignments <- c('dIndex', 'n2Index')
  vd.insertions <- "n1Insertion"
  dj.insertions <- "n2Insertion"
  total.insertions <- "NO SUCH COLUMN AT ALL 3"
  .skip = 0
  .sep = '\t'
  
  df <- parse.cloneset(.filename = filename, 
                       .nuc.seq = nuc.seq,
                       .aa.seq = aa.seq,
                       .reads = reads,
                       .barcodes = barcodes,
                       .vgenes = vgenes,
                       .jgenes = jgenes,
                       .dgenes = dgenes,
                       .vend = vend,
                       .jstart = jstart,
                       .dalignments = dalignments,
                       .vd.insertions = vd.insertions,
                       .dj.insertions = dj.insertions,
                       .total.insertions = total.insertions,
                       .skip = .skip,
                       .sep = .sep)
  
  # fix nucleotide sequences
  df$CDR3.nucleotide.sequence <- substr(df$CDR3.nucleotide.sequence, df$Umi.count + 1, nchar(df$CDR3.nucleotide.sequence) - 6)
  
  # add out-of-frame amino acid sequences
  df$CDR3.amino.acid.sequence <- bunch.translate(df$CDR3.nucleotide.sequence)
  
  # df <- fix.alleles(df)
  
  # fix genes names and ","
  .fix.genes <- function (.col) {
    # fix ","
    .col <- gsub(",", ", ", .col, fixed = T, useBytes = T)
    # fix forward zeros
    .col <- gsub("([0])([0-9])", "\\2", .col, useBytes = T)
    # fix gene names
    .col <- gsub("TCR", "TR", .col, fixed = T, useBytes = T)
    .col
  }
  
  df$V.gene <- .fix.genes(df$V.gene)
  df$D.gene <- .fix.genes(df$D.gene)
  df$J.gene <- .fix.genes(df$J.gene)
  
  # update V, D and J positions
  .fix.poses <- function (.col) {
    df[df[[.col]] != -1, .col] <- df[df[[.col]] != -1, .col] - df$Umi.count[df[[.col]] != -1]
    df
  }
  
  df <- .fix.poses("V.end")
  df <- .fix.poses("D3.end")
  df <- .fix.poses("D5.end")
  df <- .fix.poses("J.start")
  
  # nullify barcodes
  df$Umi.count <- NA
  df$Umi.proportion <- NA
  
  df
}