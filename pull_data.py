from serpapi import GoogleSearch
import os
import csv

# Fill in your serpapi api key
# Fill in desired author_id from google scholar
API_KEY = ""
AUTHOR_ID = "b4cFNacAAAAJ"
params = {
    "api_key": API_KEY, 
    "engine": "google_scholar_author",
    "author_id": AUTHOR_ID,
    "hl": "en"
}

search = GoogleSearch(params)
results = search.get_dict()

citation_data = {}
for article in results['articles']:
  article_title = article.get('title')
  article_link = article.get('link')
  article_authors = article.get('authors')
  article_publication = article.get('publication')
  cited_by = article.get('cited_by').get('value')
  cited_by_link = article.get('cited_by').get('link')
  article_year = article.get('year')

  print(f"Title: {article_title}\nLink: {article_link}\nAuthors: {article_authors}\nPublication: {article_publication}\nCited by: {cited_by}\nCited by link: {cited_by_link}\nPublication year: {article_year}\n")

  params_cite = {
      "api_key" : API_KEY,
      "engine" : "google_scholar_author",
      "view_op" : "view_citation",
      "citation_id": article.get('citation_id'),
      "hl": "en"
  }
  search2 = GoogleSearch(params_cite)
  citation = search2.get_dict()
  citation_data[article_title] = citation


timeseries_citations = results.get('cited_by').get('graph')
cite_data = []
cite_data = [[line.get("year") for line in timeseries_citations],
             [line.get("citations") for line in timeseries_citations],
             ["total" for line in timeseries_citations]]

for article in results['articles']:
  if citation_data.get(article.get('title')).get('error') is None:
    article_citations = citation_data.get(article.get('title')).get('citation').get('total_citations').get('table')
    cite_data[0].extend([line.get("year") for line in article_citations])
    cite_data[1].extend([line.get("citations") for line in article_citations])
    cite_data[2].extend([article.get('title') for line in article_citations])
  else:
    print("No cite data for %s" % article.get('title'))


write_data = []
for i in range(len(cite_data[0])):
    write_data.append([cite_data[0][i], cite_data[1][i], cite_data[2][i]])

with open("milgrom_time_series.csv", 'w') as f:
    writer = csv.writer(f)
    writer.writerows(write_data)
