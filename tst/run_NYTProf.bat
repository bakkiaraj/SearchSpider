@echo OFF
perl -d:NYTProf ../src/searchSpider.pl
nytprofhtml --open
REM nytprofcsv