library(plyr)

# 15 seconds with rgb2munsell called within each group
# 0.5 seconds without
system.time(mixed.dry <- ddply(dry.colors[dry.mix.idx, ], id.var, mix_and_clean_colors))

# nearly instant
dc <- split(dry.colors[dry.mix.idx, ], f = dry.colors[[id.var]][dry.mix.idx])
mc <- split(moist.colors[moist.mix.idx, ], f=moist.colors[[id.var]][moist.mix.idx], mix_and_clean_colors)


# 14 seconds with rgb2munsell called within each group
# 0.5 seconds without 
system.time(dc.l <- lapply(dc, mix_and_clean_colors))
system.time(mc.l <- lapply(mc, mix_and_clean_colors))
mixed.dry.2 <- do.call('rbind', dc.l)


# perform outside of groups: ~ 2 seconds
system.time(m <- rgb2munsell(mixed.dry[, -1]))


## pattern for replacement of ddply -> base
dc <- split(dry.colors[dry.mix.idx, ], f = dry.colors[[id.var]][dry.mix.idx])
dc.l <- lapply(dc, mix_and_clean_colors)
mixed.dry <- do.call('rbind', dc.l)



library(soilDB)
library(aqp)
library(microbenchmark)
library(daff)


x <- fetchKSSL(mlra=c(18, 17), returnMorphologicData = TRUE)

microbenchmark(
  old = simplifyColorData(x$morph$phcolor, id.var = 'labsampnum', wt = 'colorpct'),
  new = simplifyColorData2(x$morph$phcolor, id.var = 'labsampnum', wt = 'colorpct'),
  times = 10
  )


## differences?
cd1 <- simplifyColorData(x$morph$phcolor, id.var = 'labsampnum', wt = 'colorpct')
cd2 <- simplifyColorData2(x$morph$phcolor, id.var = 'labsampnum', wt = 'colorpct')

# only differences are due to sorting rules
d <- diff_data(cd1, cd2)
render_diff(d)




