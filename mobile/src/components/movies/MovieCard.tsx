import React from 'react';
import { View, StyleSheet, Image, TouchableOpacity } from 'react-native';
import { Text, Card, Chip } from 'react-native-paper';
import { MovieWithDetails } from '../../types';
import { Star, ThumbsUp, ThumbsDown } from 'lucide-react-native';
import { router } from 'expo-router';
import {
  getMovieTitle,
  getMovieVoteAverage,
  getMovieYear,
  getPosterUrl,
} from '../../utils/movieData';

interface MovieCardProps {
  movie: MovieWithDetails;
}

export default function MovieCard({ movie }: MovieCardProps) {
  const { recommendations, watch_history } = movie;
  const posterUrl = getPosterUrl(movie);
  const title = getMovieTitle(movie);
  const year = getMovieYear(movie);
  const voteAverage = getMovieVoteAverage(movie);

  const upvotes = recommendations.filter((r) => r.vote_type === 'upvote').length;
  const downvotes = recommendations.filter((r) => r.vote_type === 'downvote').length;

  const handlePress = () => {
    router.push(`/movie/${movie.imdb_id}`);
  };

  return (
    <TouchableOpacity onPress={handlePress}>
      <Card style={styles.card}>
        <View style={styles.container}>
          {posterUrl ? (
            <Image source={{ uri: posterUrl }} style={styles.poster} />
          ) : (
            <View style={[styles.poster, styles.posterPlaceholder]}>
              <Text variant="bodySmall" style={styles.placeholderText}>
                No Poster
              </Text>
            </View>
          )}

          <View style={styles.content}>
            <Text variant="titleMedium" style={styles.title} numberOfLines={2}>
              {title}
            </Text>

            <Text variant="bodySmall" style={styles.year}>
              {year}
            </Text>

            {voteAverage ? (
              <View style={styles.rating}>
                <Star size={14} color="#ffd700" fill="#ffd700" />
                <Text variant="bodySmall" style={styles.ratingText}>
                  {voteAverage.toFixed(1)}
                </Text>
              </View>
            ) : null}

            <View style={styles.votes}>
              {upvotes > 0 && (
                <View style={styles.voteChip}>
                  <ThumbsUp size={12} color="#34c759" />
                  <Text variant="bodySmall" style={styles.voteText}>
                    {upvotes}
                  </Text>
                </View>
              )}

              {downvotes > 0 && (
                <View style={styles.voteChip}>
                  <ThumbsDown size={12} color="#ff3b30" />
                  <Text variant="bodySmall" style={styles.voteText}>
                    {downvotes}
                  </Text>
                </View>
              )}
            </View>

            {watch_history && (
              <Chip
                icon={() => <Star size={12} color="#fff" fill="#fff" />}
                style={styles.watchedChip}
                textStyle={styles.chipText}
              >
                {watch_history.my_rating.toFixed(1)}
              </Chip>
            )}
          </View>
        </View>
      </Card>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: {
    marginHorizontal: 16,
    marginVertical: 8,
    backgroundColor: '#1c1c1e',
  },
  container: {
    flexDirection: 'row',
    padding: 12,
  },
  poster: {
    width: 80,
    height: 120,
    borderRadius: 8,
  },
  posterPlaceholder: {
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderText: {
    color: '#8e8e93',
  },
  content: {
    flex: 1,
    marginLeft: 12,
    justifyContent: 'flex-start',
  },
  title: {
    color: '#fff',
    marginBottom: 4,
  },
  year: {
    color: '#8e8e93',
    marginBottom: 8,
  },
  rating: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  ratingText: {
    color: '#fff',
    marginLeft: 4,
  },
  votes: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 8,
  },
  voteChip: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    gap: 4,
  },
  voteText: {
    color: '#fff',
  },
  watchedChip: {
    backgroundColor: '#DBA506',
    alignSelf: 'flex-start',
  },
  chipText: {
    color: '#fff',
    fontSize: 12,
  },
});
