# Copyright (c) Microsoft Corporation.  All rights reserved.

# Third Party Programs. This software enables you to obtain software applications from other sources. 
# Those applications are offered and distributed by third parties under their own license terms.
# Microsoft is not developing, distributing or licensing those applications to you, but instead, 
# as a convenience, enables you to use this software to obtain those applications directly from 
# the application providers.
# By using the software, you acknowledge and agree that you are obtaining the applications directly
# from the third party providers and under separate license terms, and that it is your responsibility to locate, 
# understand and comply with those license terms.
# Microsoft grants you no license rights for third-party software or applications that is obtained using this software.

# See also:
# http://stats.stackexchange.com/questions/5195/how-to-draw-funnel-plot-using-ggplot2-in-r/5210#5210


#DEBUG in RStudio
fileRda = "C:/Users/boefraty/projects/PBI/R/tempData.Rda"
if(file.exists(dirname(fileRda)))
{
  if(Sys.getenv("RSTUDIO")!="")
    load(file= fileRda)
  else
    save(list = ls(all.names = TRUE), file=fileRda)
}


############ User Parameters #########
# Set of parameters from GUI

##PBI_PARAM Color of scatterplot points
#Type:string, Default:"orange", Range:NA, PossibleValues:"orange","blue","green","black"
pointsCol = "orange"
if(exists("settings_scatter_params_pointColor")){
  pointsCol = settings_scatter_params_pointColor
}

#PBI_PARAM Transparency of scatterplot points
#Type:numeric, Default:0.4, Range:[0,1], PossibleValues:NA, Remarks: NA
transparency = 0.4
if(exists("settings_scatter_params_percentile")){
  transparency = settings_scatter_params_percentile/100
}

##PBI_PARAM Color of baseline
#Type:string, Default:"blue", Range:NA, PossibleValues:"orange","blue","green","black"
lineColor = "blue"
if(exists("settings_funnel_params_lineColor")){
  lineColor = settings_funnel_params_lineColor
}


#PBI_PARAM Sparsification of scatterplot points
#Type:bool, Default:TRUE, Range:NA, PossibleValues:NA, Remarks: NA
sparsify = TRUE
if(exists("settings_scatter_params_sparsify")){
  sparsify = settings_scatter_params_sparsify
}

#PBI_PARAM Size of points on the plot
#Type:numeric, Default: 1 , Range:[0.1,5], PossibleValues:NA, Remarks: NA
pointCex = 1
if(exists("settings_scatter_params_weight")){
  pointCex = min(50,max(settings_scatter_params_weight,1))/10
}


#PBI_PARAM Confidence level line
#Type:numeric, Default: 0.75 , Range:[0,1], PossibleValues:NA, Remarks: GUI input is predefined set of values
conf1 = 0.75
if(exists("settings_funnel_params_conf1")){
  conf1 = as.numeric(settings_funnel_params_conf1)
}

#PBI_PARAM Confidence level line #2
#Type:numeric, Default: 0.95 , Range:[0,1], PossibleValues:NA, Remarks: NA
conf2 = 0.95
if(exists("settings_funnel_params_conf2")){
  conf2 = as.numeric(settings_funnel_params_conf2)
}


axisXisPercentage = TRUE # ratio or percentage 
if(exists("settings_axes_params_axisXisPercentage")){
  axisXisPercentage = as.numeric(settings_axes_params_axisXisPercentage)
}

scaleXformat = "comma"
if(exists("settings_axes_params_scaleXformat")){
  scaleXformat = settings_axes_params_scaleXformat
}

scaleYformat = "none"
if(exists("settings_axes_params_scaleYformat")){
  scaleYformat = settings_axes_params_scaleYformat
}

#PBI_PARAM Size of labels on axes
sizeLabel = 12
if(exists("settings_axes_params_weight")){
  sizeLabel = settings_axes_params_weight
}

#PBI_PARAM Size of ticks on axes 
sizeTicks = 6
if(exists("settings_axes_params_sizeTicks")){
  sizeTicks = as.numeric(settings_axes_params_sizeTicks)
}
#PBI_PARAM Size of labels on axes
colLabel = "gray"
if(exists("settings_axes_params_colLabel")){
  colLabel = settings_axes_params_colLabel
}
###############Library Declarations###############

source('./r_files/flatten_HTML.r')
source('./r_files/utils.r')

libraryRequireInstall("ggplot2")
libraryRequireInstall("plotly")
libraryRequireInstall("scales")


###############Internal parameters definitions#################
# Set of parameters, which are not exported to GUI

#PBI_PARAM is vertical plot
verticalPlot = FALSE

#PBI_PARAM Minimal number of points for funnel plot
minPoints = 10

#PBI_PARAM Size of warnings font
sizeWarn = 11


###############Internal functions definitions#################

#paste tooltips together separated by <br>
generateNiceTooltips = function(dataset)
{
  myNames = names(dataset)
  LMN = length(myNames)
  s = 1; if(LMN > 2)  s = 3
  
  nms = myNames[s:LMN]
  dta = dataset[,s:LMN]
  niceTooltips = NULL
  
  for (n in c(1:length(nms)))
  {
    if(length(nms) == 1)
      niceTooltips = paste(nms," = ", dta, sep ="") 
    else
    {
      niceTooltips = paste(niceTooltips,nms[n]," = ", dta[,n], sep ="")  
      if(n < length(nms))
        niceTooltips = paste(niceTooltips,"<br>", sep ="")
    }
  }
  return(niceTooltips)
}

#tweak the limits of the axis
NiceLimitsAxis <- function(axisData, baseline =NULL, isPositive = TRUE)
{
limsA = c(min(axisData), max(axisData)) # default
if(is.null(baseline))
  baseline = sum(limsA)/2

limsA = (limsA - mean(limsA))*1.3 + baseline # centralize
limsA[1] = min(limsA[1],min(axisData)) # include outliers
limsA[2] = max(limsA[2],max(axisData)) # include outliers
if(limsA[1] < 0 && isPositive) # don't include region far away from 0
{ 
  temp = -0.02 * (limsA[2])
  limsA[1] = max(temp, limsA[1]) 
}
return(limsA)
}
############# Input validation & initializations ############# 

if(conf2 < conf1)# swap
{   temp = conf1; conf1 = conf2; conf2 = temp}

validToPlot = TRUE

pbiWarning = ""

gpd = goodPlotDimension()

if(validToPlot && !gpd) # too small canvas
{
  validToPlot = FALSE
  pbiWarning1 = "Visual is "
  pbiWarning1 = cutStr2Show(pbiWarning1, strCex = sizeWarn/6, partAvailable = 0.85)
  pbiWarning2 = "too small "
  pbiWarning2 = cutStr2Show(pbiWarning2, strCex = sizeWarn/6, partAvailable = 0.85)
  pbiWarning<-paste(pbiWarning1, "<br>", pbiWarning2, sep="")
  sizeWarn = 8 #smaller 
}

if(validToPlot && (!exists("population") ||!exists("occurrence"))) # invalid input 
{
  validToPlot = FALSE
  pbiWarning1 = "Both population and occurrence are required"
  pbiWarning = cutStr2Show(pbiWarning1, strCex = sizeWarn/6, partAvailable = 0.85)
}

if(validToPlot)
{
  population[is.na(population)] = 0
  occurrence[is.na(occurrence)] = -1
  population[is.null(population)] = 0
  occurrence[is.null(occurrence)] = -1
  
  #clean data
  validData = rep(TRUE,nrow(population))
  validData = as.logical(validData & (population > 1) & (occurrence >= 0)  & (occurrence <= population ))
}

if(validToPlot && (sum(validData) < minPoints)) # not enough data samples
{
  validToPlot = FALSE
  pbiWarning1 = "Not enough data samples"
  pbiWarning1 = cutStr2Show(pbiWarning1, strCex = sizeWarn/6, partAvailable = 0.85)
  pbiWarning2 = "for funnel plot"
  pbiWarning2 = cutStr2Show(pbiWarning2, strCex = sizeWarn/6, partAvailable = 0.85)
  pbiWarning<-paste(pbiWarning1, "<br>", pbiWarning2, sep="")
}

############# Main code #####################

if(validToPlot)
{
  if(!exists("tooltips"))
  {
    dataset = cbind(population,occurrence)
  }else{
    dataset = cbind(population,occurrence,tooltips)
  }
  
  dataset = dataset[validData,]# keep only valid
  namesDS = names(dataset)
  
  countValue = dataset[,1]
  p = dataset[,2]/dataset[,1]
  p.se <- sqrt((p*(1-p)) / (countValue))
  df <- data.frame(p, countValue, p.se)
  
  ## common effect (fixed effect model)
  p.fem <- weighted.mean(p[p.se>0], 1/p.se[p.se>0]^2)
  
  ## lower and upper limits, based on FEM estimator
  zLow = qnorm(conf1)
  zUp = qnorm(conf2)
  
  
  mult = 1
  entryWordLabelY = "Ratio of "
  if(axisXisPercentage)
  {
    mult = 100
    entryWordLabelY = "Percentage of "
  }
  
  number.seq <- seq(min(countValue), max(countValue), 1000)
  number.llconf1 <- (p.fem - zLow * sqrt((p.fem*(1-p.fem)) / (number.seq)))*mult
  number.ulconf1 <- (p.fem + zLow * sqrt((p.fem*(1-p.fem)) / (number.seq)))*mult
  number.llconf2 <- (p.fem - zUp * sqrt((p.fem*(1-p.fem)) / (number.seq)))*mult
  number.ulconf2 <- (p.fem + zUp * sqrt((p.fem*(1-p.fem)) / (number.seq)))*mult
  
  yAxis = p*mult
  p.fem = p.fem*mult
  
  dfCI <- data.frame(number.llconf1, number.ulconf1, number.llconf2, number.ulconf2, number.seq, p.fem)
  
  #tweak the limits of the y-axis
  limsY = NiceLimitsAxis(axisData = yAxis, baseline = p.fem)
  
  xLabText = cutStr2Show( namesDS[1], strCex = sizeLabel/6, isH = TRUE, partAvailable = 0.8)
  yLabText = cutStr2Show( paste(entryWordLabelY, namesDS[2], sep =""), strCex = sizeLabel/6, isH = FALSE, partAvailable = 0.8)
  
  ## draw plot
  if(sparsify)
    drawPoints = SparsifyScatter(dataset)# remove points from dense regions
  else
    drawPoints = SparsifyScatter(dataset,minMaxPoints = c(Inf,Inf))
  
  fp <- ggplot(aes(x = countValue[drawPoints], y = yAxis[drawPoints]), data = df[drawPoints,]) 
  fp <- fp + geom_point(shape = 19, colour = alpha(pointsCol,transparency), size = pointCex*2 ) 
  
  fp <- fp + geom_line(aes(x = number.seq, y = number.llconf1),linetype = 1, colour = "green",data = dfCI) 
  fp <- fp + geom_line(aes(x = number.seq, y = number.ulconf1),linetype = 1, colour = "green", data = dfCI) 
  
  fp <- fp + geom_line(aes(x = number.seq, y = number.llconf2),linetype = 2, colour = "red",data = dfCI) 
  fp <- fp + geom_line(aes(x = number.seq, y = number.ulconf2), linetype = 2, colour = "red",data = dfCI) 
  
  fp <- fp + geom_hline(aes(yintercept = p.fem), data = dfCI, colour = lineColor, linetype = 4)
  
  if(scaleYformat %in% c("none"))
    fp <- fp + scale_y_continuous(limits =limsY)
  
  if(scaleYformat %in% c("comma"))
    fp <- fp + scale_y_continuous(limits =limsY, labels = comma)
  
  if(scaleYformat %in% c("scientific"))
    fp <- fp + scale_y_continuous(limits =limsY, labels = scientific)
  
  if(scaleXformat %in% c("comma"))
    fp <- fp + scale_x_continuous(labels = comma)
  
  if(scaleXformat %in% c("dollar"))
    fp <- fp + scale_x_continuous(labels = dollar)
  
  if(scaleXformat %in% c("scientific"))
    fp <- fp + scale_x_continuous(labels = scientific)
  
  fp <- fp + xlab(xLabText) + ylab(yLabText) + theme_bw()
  
  if(verticalPlot)
    fp <- fp +  coord_flip()
  
}else{# empty plot 
  fp <- ggplot()
}

#add warning as title
fp = fp + labs (title = pbiWarning, caption = NULL) + theme_bw() + 
  theme(plot.title  = element_text(hjust = 0.5, size = sizeWarn), 
        axis.title=element_text(size =  sizeLabel, colour = colLabel),
        axis.text=element_text(size =  sizeTicks),
        panel.border = element_rect())

if(!validToPlot) # remove box from empty plot 
  fp = fp + 
  theme(panel.border = element_blank())


############# Create and save widget ###############

p = ggplotly(fp);

disabledButtonsList <- list('toImage', 'sendDataToCloud', 'zoom2d', 'pan', 'pan2d', 'select2d', 'lasso2d', 'hoverClosestCartesian', 'hoverCompareCartesian')
p$x$config$modeBarButtonsToRemove = disabledButtonsList

p <- config(p, staticPlot = FALSE, editable = FALSE, sendData = FALSE, showLink = FALSE,
            displaylogo = FALSE,  collaborate = FALSE, cloud=FALSE)

if(validToPlot)
{
  layerScatter = 1 # first layer is scatter 
  ntt = generateNiceTooltips(dataset[drawPoints,])
  #tooltips on scatter
  p$x$data[[layerScatter]]$text = ntt
  
  #tooltips on lines
  p$x$data[[2]]$text = paste(as.character(conf1*100),"% limits (l)",sep ="")
  p$x$data[[3]]$text = paste(as.character(conf1*100),"% limits (u)",sep ="")
  p$x$data[[4]]$text = paste(as.character(conf2*100),"% limits (l)",sep ="")
  p$x$data[[5]]$text = paste(as.character(conf2*100),"% limits (u)",sep ="")
  p$x$data[[6]]$text = paste("baseline ", as.character(round(p.fem,4)), sep ="")
}

internalSaveWidget(p, 'out.html')

####################################################

#DEBUG in RStudio
if(Sys.getenv("RSTUDIO")!="")
  print(p)
