\name{get_component_data_from_NASIS_db}
\alias{get_component_data_from_NASIS_db}

\title{Extract component data from a local NASIS Database}
\description{Extract component data from a local NASIS Database.}
\usage{
get_component_data_from_NASIS_db(SS = TRUE, fill = FALSE)
}
%- maybe also 'usage' for other objects documented here.
\arguments{
  \item{SS}{get data from the currently loaded Selected Set in NASIS or from the entire local database (default: TRUE)}
  \item{fill}{should missing "month" rows in the comonth table be filled with NA (FALSE)}
}	
}
\details{This function currently works only on Windows.}
\value{A list with the results.}
\author{Dylan E. Beaudette, Stephen Roecker, and Jay M. Skovlin}

%% ~Make other sections like Warning with \section{Warning }{....} ~

\seealso{
\code{\link{fetchNASIS()}}, \code{\link{fetchNASIS_components()}}
}

\examples{
\dontrun{
# query text note data
fc <- get_component_data_from_NASIS_db()

# show structure of component data returned
str(fc)

}
}
% Add one or more standard keywords, see file 'KEYWORDS' in the
% R documentation directory.
\keyword{manip}