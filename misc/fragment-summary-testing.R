library(soilDB)
library(daff)
library(plyr)
library(digest)
library(purrr)



# base table is phorizon so that NULL data can be converted to 0s later
q.rf.data <- "SELECT p.phiid, fragvol, fragsize_l, fragsize_r, fragsize_h, fragshp, fraghard 
FROM ( 
SELECT DISTINCT phiid FROM phorizon_View_1 
) as p
LEFT OUTER JOIN phfrags_View_1 ON p.phiid = phfrags_View_1.phiidref;
"

channel <- RODBC::odbcDriverConnect(connection=getOption('soilDB.NASIS.credentials'))

d <- RODBC::sqlQuery(channel, q.rf.data, stringsAsFactors=FALSE)
d <- uncode(d, stringsAsFactors = FALSE)

RODBC::odbcClose(channel)


ed <- get_extended_data_from_NASIS_db()

ed$frag_summary <- ed$frag_summary[order(ed$frag_summary$phiid), ]
ed$frag_summary_v2 <- ed$frag_summary_v2[order(ed$frag_summary_v2$phiid), ]

test <- diff_data(ed$frag_summary, ed$frag_summary_v2)
render_diff(test, title='R-based vs. SQL-based fragment summary')


checkDiffs <- function(id) {
  r.ver <- ed$frag_summary[which(ed$frag_summary$phiid %in% id), ]
  sql.ver <- ed$frag_summary_v2[which(ed$frag_summary_v2$phiid %in% id), ]
  orig <- d[which(d$phiid %in% id), ]
  
  res <- list(R=r.ver, SQL=sql.ver, original=orig)
  return(res)
}


checkDiffs('564492')
checkDiffs('564496')


## specific examples

# fragment H of 76 results in CB, should be GR
checkDiffs('1196586')
lapply(checkDiffs('1196586'), knitr::kable, row.names=FALSE)

# how many are there like this?
# ~ 30% of this collection
length(which(d$fragsize_h == 76)) / length(which(d$fragsize_h == 75))

# ~ 4% with an RV that could be used to infer the correct size class
length(which(d$fragsize_h == 76 & !is.na(d$fragsize_r))) / length(which(d$fragsize_h == 75))



# combination 76mm fragsize_h and RV of 5mm: GR vs. fine GR
checkDiffs('780056')
lapply(checkDiffs('780056'), knitr::kable, row.names=FALSE)


# size range spans multiple classes
checkDiffs('717529')
lapply(checkDiffs('717529'), knitr::kable, row.names=FALSE)



# fragsize RV and H not specified
# fragshp not specified
checkDiffs('564492')
lapply(checkDiffs('564492'), knitr::kable, row.names=FALSE)



# r-bind and eval differences
g <- rbind(ed$frag_summary[, c(1:15, 18)], ed$frag_summary_v2[, c(-16)])

# find duplicates

# convert rows to list elements
# this implicitly removes rownames
# much faster than split(x, 1:nrow(x))
xx <- transpose(g)

# performance the same as map_chr(xx, digest)
hash <- sapply(xx, digest)

# sort for RLE
idx <- order(hash)
r <- rle(hash[idx])

# locate hashes with more than 1 row
dupe.idx <- which(r$lengths > 1)

# find rows in source data within a small set of matching hashes
row.idx <- which(hash %in% r$values[dupe.idx[1:2]])

g[row.idx, ]


# find rows in source data within a small set of matching hashes
row.idx <- which(! hash %in% r$values[dupe.idx])

# differences
g.diff <- g[row.idx, ]
g.diff <- g.diff[order(g.diff$phiid), ]

