# Copyright 2018 Open Networking Foundation (ONF)
#
# Please refer questions to either the onos test mailing list at <onos-test@onosproject.org>,
# the System Testing Plans and Results wiki page at <https://wiki.onosproject.org/x/voMg>,
# or the System Testing Guide page at <https://wiki.onosproject.org/x/WYQg>
#
#     TestON is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     TestON is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with TestON.  If not, see <http://www.gnu.org/licenses/>.
#
# If you have any questions, or if you don't understand R,
# please contact Jeremy Ronquillo: j_ronquillo@u.pacific.edu

# **********************************************************
# STEP 1: Data management.
# **********************************************************

print( "**********************************************************" )
print( "STEP 1: Data management." )
print( "**********************************************************" )

# Command line arguments are read. Args include the database credentials, test name, branch name, and the directory to output files.
print( "Reading commmand-line args." )
args <- commandArgs( trailingOnly=TRUE )

databaseHost <- 1
databasePort <- 2
databaseUserID <- 3
databasePassword <- 4
testSuiteName <- 5
branchName <- 6
testsToInclude <- 7
buildToShow <- 8
saveDirectory <- 9

# ----------------
# Import Libraries
# ----------------

print( "Importing libraries." )
library( ggplot2 )
library( reshape2 )
library( RPostgreSQL )

# -------------------
# Check CLI Arguments
# -------------------

print( "Verifying CLI args." )

if ( is.na( args[ saveDirectory ] ) ){

    print( paste( "Usage: Rscript testCategoryBuildStats.R",
                                  "<database-host>",
                                  "<database-port>",
                                  "<database-user-id>",
                                  "<database-password>",
                                  "<test-suite-name>",
                                  "<branch-name>",
                                  "<tests-to-include-(as-one-string-sep-groups-by-semicolon-title-as-first-group-item-sep-by-dash)>",
                                  "<build-to-show>",
                                  "<directory-to-save-graphs>",
                                  sep=" " ) )

    quit( status = 1 )  # basically exit(), but in R
}

# ------------------
# SQL Initialization
# ------------------

print( "Initializing SQL" )

con <- dbConnect( dbDriver( "PostgreSQL" ),
                  dbname = "onostest",
                  host = args[ databaseHost ],
                  port = strtoi( args[ databasePort ] ),
                  user = args[ databaseUserID ],
                  password = args[ databasePassword ] )

# ---------------------
# Test Case SQL Command
# ---------------------

print( "Generating Test Case SQL command." )

tests <- "'"
for ( test in as.list( strsplit( args[ testsToInclude ], "," )[[1]] ) ){
    tests <- paste( tests, test, "','", sep="" )
}
tests <- substr( tests, 0, nchar( tests ) - 2 )

fileBuildToShow <- args[ buildToShow ]
operator <- "= "
buildTitle <- ""
if ( args[ buildToShow ] == "latest" ){
    buildTitle <- "\nLatest Test Results"
    operator <- ">= "
    args[ buildToShow ] <- "1000"
} else {
    buildTitle <- paste( " \n Build #", args[ buildToShow ] , sep="" )
}

tests <- strsplit( args[ testsToInclude ], ";" )
dbResults <- list()
titles <- list()

for ( i in 1:length( tests[[1]] ) ){
    splitTestList <- strsplit( tests[[1]][ i ], "-" )
    testList <- splitTestList[[1]][2]
    titles[[i]] <- splitTestList[[1]][1]

    testsCommand <- "'"
    for ( test in as.list( strsplit( testList, "," )[[1]] ) ){
        testsCommand <- paste( testsCommand, test, "','", sep="" )
    }
    testsCommand <- substr( testsCommand, 0, nchar( testsCommand ) - 2 )

    command <- paste( "SELECT * ",
                      "FROM executed_test_tests a ",
                      "WHERE ( SELECT COUNT( * ) FROM executed_test_tests b ",
                      "WHERE b.branch='",
                      args[ branchName ],
                      "' AND b.actual_test_name IN (",
                      testsCommand,
                      ") AND a.actual_test_name = b.actual_test_name AND a.date <= b.date AND b.build ", operator,
                      args[ buildToShow ],
                      " ) = ",
                      1,
                      " AND a.branch='",
                      args[ branchName ],
                      "' AND a.actual_test_name IN (",
                      testsCommand,
                      ") AND a.build ", operator,
                      args[ buildToShow ],
                      " ORDER BY a.actual_test_name DESC, a.date DESC",
                      sep="")
    print( "Sending SQL command:" )
    print( command )
    dbResults[[i]] <- dbGetQuery( con, command )
}

print( "dbResult:" )
print( dbResults )

# -------------------------------
# Create Title and Graph Filename
# -------------------------------

print( "Creating title of graph." )

titlePrefix <- paste( args[ testSuiteName ], " ", sep="" )
if ( args[ testSuiteName ] == "ALL" ){
    titlePrefix <- ""
}

title <- paste( titlePrefix,
                "Summary of Test Suites - ",
                args[ branchName ],
                buildTitle,
                sep="" )

print( "Creating graph filename." )

outputFile <- paste( args[ saveDirectory ],
                     args[ testSuiteName ],
                     "_",
                     args[ branchName ],
                     "_build-",
                     fileBuildToShow,
                     "_test-suite-summary.jpg",
                     sep="" )

# **********************************************************
# STEP 2: Organize data.
# **********************************************************

print( "**********************************************************" )
print( "STEP 2: Organize Data." )
print( "**********************************************************" )

passNum <- list()
failNum <- list()
exeNum <- list()
skipNum <- list()
totalNum <- list()

passPercent <- list()
failPercent <- list()
exePercent <- list()
nonExePercent <- list()

actualPassPercent <- list()
actualFailPercent <- list()

appName <- c()
afpName <- c()
nepName <- c()

tmpPos <- c()
tmpCases <- c()

for ( i in 1:length( dbResults ) ){
    t <- dbResults[[i]]

    passNum[[i]] <- sum( t$num_passed )
    failNum[[i]] <- sum( t$num_failed )
    exeNum[[i]] <- passNum[[i]] + failNum[[i]]
    totalNum[[i]] <- sum( t$num_planned )
    skipNum[[i]] <- totalNum[[i]] - exeNum[[i]]

    passPercent[[i]] <- passNum[[i]] / exeNum[[i]]
    failPercent[[i]] <- failNum[[i]] / exeNum[[i]]
    exePercent[[i]] <- exeNum[[i]] / totalNum[[i]]
    nonExePercent[[i]] <- ( 1 - exePercent[[i]] ) * 100

    actualPassPercent[[i]] <- passPercent[[i]] * exePercent[[i]] * 100
    actualFailPercent[[i]] <- failPercent[[i]] * exePercent[[i]] * 100

    appName <- c( appName, "Passed" )
    afpName <- c( afpName, "Failed" )
    nepName <- c( nepName, "Skipped/Unexecuted" )

    tmpPos <- c( tmpPos, 100 - ( nonExePercent[[i]] / 2 ), actualPassPercent[[i]] + actualFailPercent[[i]] - ( actualFailPercent[[i]] / 2 ), actualPassPercent[[i]] - ( actualPassPercent[[i]] / 2 ) )
    tmpCases <- c( tmpCases, skipNum[[i]], failNum[[i]], passNum[[i]] )
}

relativePosLength <- length( dbResults ) * 3

relativePos <- c()
relativeCases <- c()

for ( i in 1:3 ){
    relativePos <- c( relativePos, tmpPos[ seq( i, relativePosLength, 3 ) ] )
    relativeCases <- c( relativeCases, tmpCases[ seq( i, relativePosLength, 3 ) ] )
}
names( actualPassPercent ) <- appName
names( actualFailPercent ) <- afpName
names( nonExePercent ) <- nepName

labels <- paste( titles, "\n", totalNum, " Test Cases", sep="" )

# --------------------
# Construct Data Frame
# --------------------

print( "Constructing Data Frame" )

dataFrame <- melt( c( nonExePercent, actualFailPercent, actualPassPercent ) )
dataFrame$title <- seq( 1, length( dbResults ), by = 1 )
colnames( dataFrame ) <- c( "perc", "key", "suite" )

dataFrame$xtitles <- labels
dataFrame$relativePos <- relativePos
dataFrame$relativeCases <- relativeCases
dataFrame$valueDisplay <- c( paste( round( dataFrame$perc, digits = 2 ), "% - ", relativeCases, " Tests", sep="" ) )

dataFrame$key <- factor( dataFrame$key, levels=unique( dataFrame$key ) )

dataFrame$willDisplayValue <- dataFrame$perc > 15.0 / length( dbResults )

for ( i in 1:nrow( dataFrame ) ){
    if ( relativeCases[[i]] == "1" ){
        dataFrame[ i, "valueDisplay" ] <- c( paste( round( dataFrame$perc[[i]], digits = 2 ), "% - ", relativeCases[[i]], " Test", sep="" ) )
    }
    if ( !dataFrame[ i, "willDisplayValue" ] ){
        dataFrame[ i, "valueDisplay" ] <- ""
    }
}

print( "Data Frame Results:" )
print( dataFrame )

# **********************************************************
# STEP 3: Generate graphs.
# **********************************************************

print( "**********************************************************" )
print( "STEP 3: Generate Graph." )
print( "**********************************************************" )

# -------------------
# Main Plot Generated
# -------------------

print( "Creating main plot." )
# Create the primary plot here.
# ggplot contains the following arguments:
#     - data: the data frame that the graph will be based off of
#    - aes: the asthetics of the graph which require:
#        - x: x-axis values (usually iterative, but it will become build # later)
#        - y: y-axis values (usually tests)
#        - color: the category of the colored lines (usually status of test)

# -------------------
# Main Plot Formatted
# -------------------

print( "Formatting main plot." )
mainPlot <- ggplot( data = dataFrame, aes( x = suite,
                                           y = perc,
                                           fill = key ) )

# ------------------------------
# Fundamental Variables Assigned
# ------------------------------

print( "Generating fundamental graph data." )

theme_set( theme_grey( base_size = 26 ) )   # set the default text size of the graph.

xScaleConfig <- scale_x_continuous( breaks = dataFrame$suite,
                                    label = dataFrame$xtitles )
yScaleConfig <- scale_y_continuous( breaks = seq( 0, 100,
                                    by = 10 ) )

xLabel <- xlab( "" )
yLabel <- ylab( "Total Test Cases (%)" )

imageWidth <- 15
imageHeight <- 10
imageDPI <- 200

# Set other graph configurations here.
theme <- theme( plot.title = element_text( hjust = 0.5, size = 32, face ='bold' ),
                axis.text.x = element_text( angle = 0, size = 25 - 1.25 * length( dbResults ) ),
                legend.position = "bottom",
                legend.text = element_text( size = 22 ),
                legend.title = element_blank(),
                legend.key.size = unit( 1.5, 'lines' ),
                plot.subtitle = element_text( size=16, hjust=1.0 ) )

subtitle <- paste( "Last Updated: ", format( Sys.time(), format = "%b %d, %Y at %I:%M %p %Z" ), sep="" )

title <- labs( title = title, subtitle = subtitle )

# Store plot configurations as 1 variable
fundamentalGraphData <- mainPlot +
                        xScaleConfig +
                        yScaleConfig +
                        xLabel +
                        yLabel +
                        theme +
                        title

# ---------------------------
# Generating Bar Graph Format
# ---------------------------

print( "Generating bar graph." )

unexecutedColor <- "#CCCCCC"    # Gray
failedColor <- "#E02020"        # Red
passedColor <- "#16B645"        # Green

colors <- scale_fill_manual( values=c( if ( "Skipped/Unexecuted" %in% dataFrame$key ){ unexecutedColor },
                                       if ( "Failed" %in% dataFrame$key ){ failedColor },
                                       if ( "Passed" %in% dataFrame$key ){ passedColor } ) )

barGraphFormat <- geom_bar( stat = "identity", width = 0.8 )

barGraphValues <- geom_text( aes( x = dataFrame$suite,
                                  y = dataFrame$relativePos,
                                  label = format( paste( dataFrame$valueDisplay ) ) ),
                                  size = 15.50 / length( dbResults ) + 2.33, fontface = "bold" )

result <- fundamentalGraphData +
          colors +
          barGraphFormat +
          barGraphValues

# -----------------------
# Exporting Graph to File
# -----------------------

print( paste( "Saving result graph to", outputFile ) )

tryCatch( ggsave( outputFile,
                  width = imageWidth,
                  height = imageHeight,
                  dpi = imageDPI ),
          error = function( e ){
              print( "[ERROR] There was a problem saving the graph due to a graph formatting exception.  Error dump:" )
              print( e )
              quit( status = 1 )
          }
        )

print( paste( "[SUCCESS] Successfully wrote result graph out to", outputFile ) )
quit( status = 0 )
