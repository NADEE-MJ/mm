import React from 'react';
import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { router } from 'expo-router';
import { Star, ThumbsDown, ThumbsUp } from 'lucide-react-native';
import { MovieWithDetails } from '../../types';
import { COLORS } from '../../utils/constants';
import { getMovieTitle, getMovieVoteAverage, getMovieYear, getPosterUrl } from '../../utils/movieData';

interface MovieCardProps {
  movie: MovieWithDetails;
}

function getStatusLabel(status: MovieWithDetails['status']['status']) {
  switch (status) {
    case 'watched':
      return 'Watched';
    case 'custom':
      return 'In List';
    case 'deleted':
      return 'Deleted';
    default:
      return 'To Watch';
  }
}

export default function MovieCard({ movie }: MovieCardProps) {
  const posterUrl = getPosterUrl(movie);
  const title = getMovieTitle(movie);
  const year = getMovieYear(movie);
  const voteAverage = getMovieVoteAverage(movie);

  const upvotes = movie.recommendations.filter((r) => r.vote_type === 'upvote').length;
  const downvotes = movie.recommendations.filter((r) => r.vote_type === 'downvote').length;

  return (
    <Pressable
      onPress={() => router.push(`/movie/${movie.imdb_id}`)}
      style={({ pressed }) => [styles.row, pressed && styles.pressed]}
    >
      {posterUrl ? (
        <Image source={{ uri: posterUrl }} style={styles.poster} />
      ) : (
        <View style={[styles.poster, styles.posterPlaceholder]}>
          <Text style={styles.posterPlaceholderText}>No Poster</Text>
        </View>
      )}

      <View style={styles.content}>
        <Text style={styles.title} numberOfLines={2}>
          {title}
        </Text>

        <View style={styles.metaRow}>
          <Text style={styles.metaText}>{year}</Text>
          {voteAverage ? (
            <View style={styles.ratingWrap}>
              <Star size={12} color="#ffd60a" fill="#ffd60a" />
              <Text style={styles.metaText}>{voteAverage.toFixed(1)}</Text>
            </View>
          ) : null}
        </View>

        <View style={styles.voteRow}>
          {upvotes > 0 ? (
            <View style={styles.votePill}>
              <ThumbsUp size={12} color={COLORS.success} />
              <Text style={styles.voteText}>{upvotes}</Text>
            </View>
          ) : null}

          {downvotes > 0 ? (
            <View style={styles.votePill}>
              <ThumbsDown size={12} color={COLORS.error} />
              <Text style={styles.voteText}>{downvotes}</Text>
            </View>
          ) : null}
        </View>
      </View>

      <View style={styles.rightArea}>
        {movie.watch_history ? (
          <View style={styles.myRatingPill}>
            <Star size={12} color="#fff" fill="#fff" />
            <Text style={styles.myRatingText}>{movie.watch_history.my_rating.toFixed(1)}</Text>
          </View>
        ) : (
          <Text style={styles.statusText}>{getStatusLabel(movie.status.status)}</Text>
        )}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    marginHorizontal: 16,
    marginBottom: 10,
    borderRadius: 12,
    backgroundColor: COLORS.surfaceGroup,
    borderWidth: 0.5,
    borderColor: COLORS.separator,
    padding: 10,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  pressed: {
    opacity: 0.75,
  },
  poster: {
    width: 58,
    height: 84,
    borderRadius: 8,
    backgroundColor: '#2c2c2e',
  },
  posterPlaceholder: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  posterPlaceholderText: {
    color: COLORS.textSecondary,
    fontSize: 10,
    textAlign: 'center',
    paddingHorizontal: 4,
  },
  content: {
    flex: 1,
    minWidth: 0,
  },
  title: {
    color: COLORS.text,
    fontSize: 16,
    fontWeight: '600',
  },
  metaRow: {
    marginTop: 4,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  metaText: {
    color: COLORS.textSecondary,
    fontSize: 13,
  },
  ratingWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  voteRow: {
    marginTop: 10,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  votePill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 10,
    backgroundColor: '#2c2c2e',
  },
  voteText: {
    color: COLORS.text,
    fontSize: 12,
    fontWeight: '600',
  },
  rightArea: {
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    minHeight: 84,
  },
  myRatingPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: COLORS.primary,
    paddingHorizontal: 8,
    paddingVertical: 5,
    borderRadius: 10,
  },
  myRatingText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '700',
  },
  statusText: {
    color: COLORS.textSecondary,
    fontSize: 12,
    fontWeight: '600',
  },
});
