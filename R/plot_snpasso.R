#' Plot SNP associations
#'
#' Plot SNP associations, with possible expansion from distinct snps to all snps.
#'
#' @param scan1output Output of \code{\link[qtl2scan]{scan1}} using
#' SNP probabilities derived by
#' \code{\link[qtl2scan]{genoprob_to_snpprob}}.
#'
#' @param snpinfo Data frame with SNP information with the following
#'     columns (the last three are generally derived from with
#'     \code{\link[qtl2scan]{index_snps}}):
#' \itemize{
#' \item \code{chr} - Character string or factor with chromosome
#' \item \code{pos} - Position (in same units as in the \code{"map"}
#'     attribute in \code{genoprobs}.
#' \item \code{sdp} - Strain distribution pattern: an integer, between
#'     1 and \eqn{2^n - 2} where \eqn{n} is the number of strains, whose
#'     binary encoding indicates the founder genotypes
#' \item \code{snp} - Character string with SNP identifier (if
#'     missing, the rownames are used).
#' \item \code{index} - Indices that indicate equivalent
#'     groups of SNPs.
#' \item \code{intervals} - Indexes that indicate which marker
#'     intervals the SNPs reside.
#' \item \code{on_map} - Indicate whether SNP coincides with a marker
#'     in the \code{genoprobs}
#' }
#'
#' @param show_all_snps If TRUE, expand to show all SNPs.
#'
#' @param add If TRUE, add to current plot (must have same map and
#' chromosomes).
#'
#' @param cex Character expansion for the points (default 0.5)
#'
#' @param pch Plotting character for the points (default 16)
#'
#' @param drop.hilit SNPs with LOD score within this amount of the maximum SNP association will be highlighted.
#'
#' @param col.hilit Color of highlighted points
#'
#' @param col Color of other points
#'
#' @param gap Gap between chromosomes.
#'
#' @param ylim y-axis limits
#'
#' @param bgcolor Background color for the plot.
#'
#' @param altbgcolor Background color for alternate chromosomes.
#'
#' @param ... Additional graphics parameters.
#'
#' @examples
#' \dontrun{
#' # load example DO data from web
#' library(qtl2geno)
#' file <- paste0("https://raw.githubusercontent.com/rqtl/",
#'                "qtl2data/master/DOex/DOex.zip")
#' DOex <- read_cross2(file)
#'
#' # subset to chr 2
#' DOex <- DOex[,"2"]
#'
#' # calculate genotype probabilities and convert to allele probabilities
#' pr <- calc_genoprob(DOex, error_prob=0.002)
#' apr <- genoprob_to_alleleprob(pr)
#'
#' # download snp info from web
#' tmpfile <- tempfile()
#' file <- paste0("https://raw.githubusercontent.com/rqtl/",
#'                "qtl2data/master/DOex/c2_snpinfo.rds")
#' download.file(file, tmpfile, quiet=TRUE)
#' snpinfo <- readRDS(tmpfile)
#' unlink(tmpfile)
#'
#' # calculate strain distribution patterns
#' library(qtl2scan)
#' snpinfo$sdp <- calc_sdp(snpinfo[,-(1:4)])
#'
#' # identify equivalent snps
#' snpinfo <- index_snps(DOex$pmap, snpinfo)
#'
#' # convert to snp probabilities
#' snp_pr <- genoprob_to_snpprob(apr, snpinfo)
#'
#' # perform SNP association analysis (here, ignoring residual kinship)
#' out_snps <- scan1(snp_pr, DOex$pheno)
#'
#' # plot results
#' library(qtl2plot)
#' plot_snpasso(out_snps, snpinfo)
#'
#' # can also just type plot()
#' plot(out_snps, snpinfo)
#'
#' # plot just subset of distinct SNPs
#' plot_snpasso(out_snps, snpinfo, show_all_snps=FALSE)
#'
#' # highlight the top snps (with LOD within 1.5 of max)
#' plot(out_snps, snpinfo, drop.hilit=1.5)
#' }
#'
#' @seealso \code{\link{plot_scan1}}, \code{\link{plot_coef}}, \code{\link{plot_coefCC}}
#' @export
#'
plot_snpasso <-
    function(scan1output, snpinfo, show_all_snps=TRUE, drop.hilit=NA,
             col.hilit="violetred", col="darkslateblue",
             pch=16, cex=0.5, ylim=NULL, add=FALSE, gap=25,
             bgcolor="gray90", altbgcolor="gray85", ...)
{
    uindex <- unique(snpinfo$index)
    if(length(uindex) != nrow(scan1output))
        stop("Something is wrong with snpinfo$index.\n",
             "      length(unique(snpinfo$index)) [",
             length(unique(snpinfo$index)), "] != nrow(scan1output) [",
             nrow(scan1output), "].")

    if(any(snpinfo$index[uindex] != uindex))
        stop("Something is wrong with snpinfo$index.\n",
             "      snpinfo$index[u] should == u for values in snpinfo$index")

    map <- snpinfo_to_map(snpinfo)

    if(show_all_snps) {
        tmp <- expand_snp_results(scan1output, map, snpinfo)
        scan1output <- tmp$lod
        map <- tmp$map
    }

    # maximum LOD
    maxlod <- max(unclass(scan1output)[,1], na.rm=TRUE)

    if(is.null(ylim))
        ylim <- c(0, maxlod*1.02)

    if(!is.na(drop.hilit) && !is.null(drop.hilit))
        col <- c(col, col.hilit)[(scan1output >= maxlod-drop.hilit)+1]

    plot_scan1(scan1output, map, lodcolumn=1, bgcolor=bgcolor, altbgcolor=altbgcolor, ylim=ylim,
               gap=gap, add=add, col = col, type="p", cex=cex, pch=pch, ...)
}


# expand snp association results according to snpinfo
expand_snp_results <-
    function(snp_results, map, snpinfo)
{
    snpinfo <- split(snpinfo, snpinfo$chr)

    if(length(map) != length(snpinfo))
        stop("length(map) [", length(map), "] != length(snpinfo) [",
             length(snpinfo), "]")

    if(nrow(snp_results) != length(unlist(map)))
        stop("nrow(snp_results) [", nrow(snp_results), "] != length(unlist(map)) [",
             length(unlist(map)), "]")

    lodindex <- split(1:nrow(snp_results), rep(names(map), vapply(map, length, 0)))

    result <- NULL
    for(i in seq(along=map)) {
        revindex <- rev_snp_index(snpinfo[[i]])

        map[[i]] <- snpinfo[[i]]$pos
        names(map[[i]]) <- snpinfo[[i]]$snp
        result <- rbind(result, unclass(snp_results)[lodindex[[i]],,drop=FALSE][revindex,,drop=FALSE])
        rownames(result) <- snpinfo[[i]]$snp
    }

    list(lod=result,
         map=map)
}

# snpinfo to map
snpinfo_to_map <-
    function(snpinfo)
{
    uindex <- sort(unique(snpinfo$index))
    if(any(snpinfo$index < 1 | snpinfo$index > nrow(snpinfo)))
        stop("snpinfo$index values outside of range [1, ",
             nrow(snpinfo), "]")

    uchr <- unique(snpinfo$chr)
    chr <- factor(snpinfo$chr, levels=uchr)

    map <- split(snpinfo$pos, chr)
    snp <- split(snpinfo$snp, chr)
    index <- split(snpinfo$index, chr)
    for(i in seq(along=map)) {
        u <- unique(index[[i]])
        map[[i]] <- map[[i]][u]
        names(map[[i]]) <- snp[[i]][u]
    }

    names(map) <- uchr

    map
}

# reverse index
rev_snp_index <-
    function(snpinfo)
{
    index_spl <- split(1:nrow(snpinfo), snpinfo$index)
    revindex <- rep(seq(along=index_spl), vapply(index_spl, length, 1))
    revindex[unlist(index_spl)] <- revindex

    revindex
}
