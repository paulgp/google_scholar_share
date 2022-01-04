library(tidyverse)
library(ggrepel)
time_series <- read_csv("~/repos/google_scholar_share/time_series.csv", 
                        col_names = c("year", "cites", "paper"))


total_cites = time_series %>% filter(paper == "total")
paper_cites = time_series %>% filter(paper != "total")

residual_cites = paper_cites %>% 
  group_by(year) %>% summarize(cites = sum(cites)) %>%
  inner_join(total_cites %>% rename(total = cites) %>% select(-paper)) %>%
  mutate(paper = "All other papers") %>%
  mutate(cites = total - cites)

plot_data = paper_cites %>% 
  inner_join(total_cites %>% rename(total = cites) %>% select(-paper)) %>%
  bind_rows(residual_cites) %>%
  mutate(share = case_when(year == 2021 ~ scales::percent(round(cites / total, digits = 2),accuracy=1))) %>%
  mutate(paper_trim = str_trunc(paper, width = 60))

new_levels = plot_data %>% filter(year == 2021) %>% mutate(temp = cites/total) %>%
  arrange(temp) %>% pull(paper_trim)

ggplot(data = plot_data %>% mutate(paper_trim = factor(paper_trim, levels = new_levels)), 
       aes(y = cites, x = year)) +
  geom_col(aes(fill = paper_trim), color = "black") +
  geom_text(aes(group = paper_trim, label = share),
            position = position_stack(vjust = 0.5)) +
  theme_minimal() +
  labs(title = "Cites from Google Scholar for Paul Goldsmith-Pinkham over time",
         y     = "",
         subtitle = "Top 20 papers",
       fill = "Paper Title",
       x = "") +
  scale_x_continuous(breaks = c(2009,2013,2017,2021), labels = c(2009,2013,2017,2021))
