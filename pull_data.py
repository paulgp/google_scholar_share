from serpapi import GoogleSearch
import os
import csv

# Fill in your serpapi api key
# Fill in desired author_id from google scholar
API_KEY = ""
AUTHOR_ID = ""
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
  article_title = article['title']
  article_link = article['link']
  article_authors = article['authors']
  article_publication = article['publication']
  cited_by = article['cited_by']['value']
  cited_by_link = article['cited_by']['link']
  article_year = article['year']

  print(f"Title: {article_title}\nLink: {article_link}\nAuthors: {article_authors}\nPublication: {article_publication}\nCited by: {cited_by}\nCited by link: {cited_by_link}\nPublication year: {article_year}\n")

  params_cite = {
      "api_key" : API_KEY,
      "engine" : "google_scholar_author",
      "view_op" : "view_citation",
      "citation_id": article['citation_id'],
      "hl": "en"
  }
  search2 = GoogleSearch(params_cite)
  citation = search2.get_dict()
  citation_data[article_title] = citation


timeseries_citations = results['cited_by']['graph']
cite_data = []
cite_data = [[line["year"] for line in timeseries_citations], [line["citations"] for line in timeseries_citations], ["total" for line in timeseries_citations]]

for article in results['articles']:
    try:
        article_citations = citation_data[article['title']]['citation']['total_citations']['table']
        cite_data[0].extend([line["year"] for line in article_citations])
        cite_data[1].extend([line["citations"] for line in article_citations])
        cite_data[2].extend([article['title'] for line in article_citations])
    except KeyError:
        print("No Data", article)


write_data = []
for i in range(len(cite_data[0])):
    write_data.append([cite_data[0][i], cite_data[1][i], cite_data[2][i]])

with open("time_series.csv", 'w') as f:
    writer = csv.writer(f)
    writer.writerows(write_data)
