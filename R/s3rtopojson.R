#' Translate delta-encoded integer coordinates to absolute coordinates
#' @param arc line-string of delta-encoded integer coordinates
#' @param scale scaling to apply to x and y 
#' @param translate to apply to x and y 
#' @export
#' @return list of absolute coordinates (often longitude,latitude) 
rel2abs <- function(arc, scale=Null, translate=Null) {
  if (!is.null(scale) & !is.null(translate)) {
    a <- 0
    b <- 0
    lapply(arc,function(point) {    
      a <<- a + point[[1]]
      b <<- b + point[[2]]
      x <- scale[1]*a + translate[1]
      y <- scale[2]*b + translate[2]
      c(x, y)})
  } else {
    c(arc[1], arc[2])
  }
}

library("rjson")
library("bitops")

# Because JSON stores 0 index values for arrays, the TopoJSON spec uses
# bitflipping to store negative indices to avoid confusion with 0.
# For example, -1 referse to the inverse arc of 0.  
bitflipper <- function(i) {
  if (i >= 0) {i = i} else {i = bitFlip(i)}
}

#' Turns polygons in a given TopoJSON object into a list of sp polygons
#' @description For a given arc index, which is a list of the arcs which belong 
#' a TopoJSON object, this function pulls the necessary arcs, calling \code{\link{rel2abs}}
#' to convert them from delta-encoded to absolute coordinates, and where necessary, flipping 
#' arcs which must be referred to in reverse to make a continuous polygon.  This is necessary because
#' TopoJSON indexes some arcs as "positive" and others as "negative" integers
#' to allow for arcs which can be either "right" or "left" of a given polygon, TopoJSON 
#' 
#' Note that because the goal of this package is to work with external data
#' the examples below are based on a parsed JSON file.  Examples can be found in the
#' inst/extdata directory.  
#' For example, to open and parse a topojson file on swiss "cantons" one would:
#' \code{swiss_data <- "inst/extdata/swissborders.topojson"}
#' \code{swiss_poly <- fromJSON(paste(readLines(swiss_data), collapse=""))}
#' 
#' @param topojson_object is a TopoJSON "Polygon" which contains, at the least, an index of arrays, and often
#' contains a names and other variables
#' @param scale scaling to apply to x and y 
#' @param translate to apply to x and y 
#' @param arcs line-strings of delta-encoded integer coordinates for all features in the TopoJSON file
#' @return list of sp Polygons
#' @examples
#' swiss_objects <- swiss_poly$objects$"swiss-cantons"$geometries
#' arcs <- swiss_poly$arcs
#' scale <- swiss_poly$transform$scale
#' translate <- swiss_poly$transform$translate
#' object_types <- lapply(swiss_objects,function(x){x$type})
#' sppolys <- lapply(swiss_objects[which(object_types=="Polygon")],topo_poly_to_sp_poly,scale,translate,arcs)
#' p2 <- Polygons(list(sppolys[[1]]),ID="a")
#' p3 <- SpatialPolygons(list(p2))
#' plot(p3)
#' @export
topo_poly_to_sp_poly <- function(topojson_object,scale,translate,arcs) {

# from the inside out:
# 1) flip bits for "the one's complement" (e.g. reversed arcs like -12)
# 2) add +1 to the index b/c of R's list indexes
# 3) subset all arcs from the total set for the object
# 4) apply the transformation to each arc and output as list
arc_index <- topojson_object$arcs[[1]]
abs_obj <- lapply(arcs[sapply(arc_index,bitflipper)+1],rel2abs,scale,translate)

# flip the arcs with negative indices
abs_obj[which(arc_index<0)] <- lapply(abs_obj[which(arc_index<0)],rev)

# from inside out:
# 1)flatten list of arcs
# 2)make a 2-dimensional matrix from them
# 3)make an sp polygon class
Polygon(do.call(rbind,unlist(abs_obj,recursive=FALSE)))

}


#' Plots a list of SP Polygons
#' @param polylist list of sp 'Polygon'
#' @param names vector of names for the polygons, optional
#' @return a SpatialPolygons object and a plot
#' @export
plotpolys <- function(polylist,names=c()) {
  if(length(names) == 0) {names = as.character(c(1:length(polylist)))} else {}
  cons <- list()
  for(i in 1:length(polylist)){
    print(str(polylist[i]))
    cons[i] <- Polygons(polylist[i], names[i])
  }
  p3 <- SpatialPolygons(cons,1:length(cons))
  plot(p3)
}

#' single arc to an sp "line" class
arc2sp.line <- function(arq,scale,translate) {
  zp <- lapply(arq,rel2abs,scale,translate)
  Line(matrix(unlist(zp),ncol=2,byrow=TRUE))
}

#' list of arcs to an sp SpatialLines class
#' @param arqs topojson arcs from rtopojson class
#' @return a SpatialLines object
#' @export
arcs2sp.line <-function(arqs,scale,translate) {
  z = list()
  for(i in seq_along(arqs)){
    z[i] <- Lines(list(arc2sp.line(arqs[i],scale,translate)),ID=as.character(i))    
  }
  SpatialLines(z)
}

# Because JSON stores 0 index values for arrays, the TopoJSON spec uses
# bitflipping to store negative indices to avoid confusion with 0.
# For example, -1 referse to the inverse arc of 0.  
#also, because of r's no-zero index on things
#need to add +1 to all arcs to get the right r arc's
bitflipper2 <- function(i) {
  if (i >= 0) {i = i} else {i = bitFlip(i)}
  i <- i+1
  i
}

#get distance of a set of points to an arc
#return as vector
#take spatialpointsdataframe, arc number
#example usage: pts.arc.dist(arcnum=1,polypoints=ply.pnts,spplys=currentpoly)
pts.arc.dist <- function(ln1,polypoints) {
  snp <- snapPointsToLines(polypoints,ln1)
  dst <- list()  
  for(i in seq_along(polypoints)) {
    dst[i] <- gDistance(polypoints[i,],snp[i,])
  }
  dst <- unlist(dst)
}
#would be nice to be able to call a Plot function on this above

#ideal function - 
#given an arc:
#gets the adjacent polygons, plots them (needs polygon data)
#gets points within those polygons, plots them (needs point data)
#gets distance of points in a given polygon to the arc, plots boxplot

#takes arc number, points, and polygons
#plots two polygons, two sets of points, highlights arc, and plots two boxplots (ideally with one flipped)
plot.pts.arc.dist <- function(arcnum,polypoints,polys,breaks) {
  ln1 <- ab.arcs[arcnum]
  plot(polys)
  plot(polypoints,add=TRUE)
  plot(ln1,add=TRUE,col="blue")
  dst <- pts.arc.dist(ln1,polypoints)
  polypoints@data <- cbind(polypoints@data,dstbin=cut(dst,breaks=breaks))
  boxplot(lm.pc.all.residuals~dstbin,data=polypoints,varwidth=T)
  dst  
}

#create arc/polyindex for topojson
#takes topojson
#returns a matrix
#with topojson arcids, polygon ids, and positive ID's
arcp.indx <- function(topojson) {
  geoms <- topojson$geometries
  m <- matrix(numeric(0), 0,2)
  for(i in seq_along(geoms)) {
    m <- rbind(m,(cbind(c(unlist(geoms[[i]]$arcs)),c(i))))
  }
  pstv <- sapply(m[,1],bitflipper2)
  m <- cbind(m,pstv)
#  colnames(m) <- c("arcid","polyid","pstv.id")
  m
}

#get all arc lengths
#returns vector of lengths
arclengths <- function(arcs) {
  ab.arcs.lengths = c()
  for(i in seq_along(ab.arcs)) {
    ab.arcs.lengths[i] <- SpatialLinesLengths(ab.arcs[i])
  }
  ab.arcs.lengths
}

#returns matrix where column headers are arc index numbers from
#topojson arcs used for distance
#example usage: pts.poly.arcs.dist(6,abt,m1.lm.pca.residuals,ab)
pts.poly.arcs.dist <- function(arcnum,plynum,topopolys,spnts,spplys,breaks=7) {
  ply.pnts <- subset(spnts,abpolyID==plynum)
  if(length(ply.pnts)!=0) {    
    currentpoly <- spplys[plynum,]
    plot(spplys)
    plot(currentpoly,add=TRUE,col="red")
    plot(currentpoly)
    plot(ply.pnts,add=TRUE)
  #  h.arcs.flpd <- sapply(h.arcs,bitflipper2)
  #  print(h.arcs.flpd)
    tmp.lst <- plot.pts.arc.dist(arcnum=arcnum,polypoints=ply.pnts,poly=currentpoly,breaks=breaks)
  }
}

arc.nbrs.t <- function(arcnum,plynum,topopolys,spnts,spplys) {
  ply.pnts <- subset(spnts,abpolyID==plynum)
}

# example: pctn.wthn.arc.dist(arcnum=v[1],polypoints=ply.pnts,poly=currentpoly,breaks=breaks)
# returns index of points which are within specified percent distance (default 15%) of arc
prcnt.wthn.idx <- function(arc,polypoints,prcnt.dst=0.15) {
  dst <- pts.arc.dist(arc,polypoints)
  close.logical <- dst<=quantile(dst,c(prcnt.dst))
  close.logical
}
