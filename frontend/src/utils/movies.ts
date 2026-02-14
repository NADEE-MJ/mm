import { MOVIE_STATUS } from "./constants";

export const MOVIE_TAB_CONFIG = {
  toWatch: { label: "To Watch", status: MOVIE_STATUS.TO_WATCH, defaultSort: "dateRecommended" },
  watched: { label: "Watched", status: MOVIE_STATUS.WATCHED, defaultSort: "dateWatched" },
};

export const MOVIE_SORT_LABELS = {
  dateRecommended: "Date Added",
  dateWatched: "Date Watched",
  myRating: "My Rating",
  imdbRating: "IMDb Rating",
  year: "Year",
  title: "Title",
};

export const MOVIE_SORT_OPTIONS_BY_STATUS = {
  [MOVIE_STATUS.WATCHED]: ["dateWatched", "myRating", "imdbRating", "year", "title"],
  [MOVIE_STATUS.TO_WATCH]: ["dateRecommended", "imdbRating", "year", "title"],
};

export function getSortOptionsForStatus(status) {
  return MOVIE_SORT_OPTIONS_BY_STATUS[status] || MOVIE_SORT_OPTIONS_BY_STATUS[MOVIE_STATUS.TO_WATCH];
}

export function getDefaultSortForStatus(status) {
  return status === MOVIE_STATUS.WATCHED ? "dateWatched" : "dateRecommended";
}
