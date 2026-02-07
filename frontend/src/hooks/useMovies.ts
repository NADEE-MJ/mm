/**
 * useMovies hook
 * Compatibility wrapper over MoviesContext.
 */

import { useMoviesContext } from "../contexts/MoviesContext";

export function useMovies() {
  return useMoviesContext();
}

