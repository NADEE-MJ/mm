import { ThumbsUp, ThumbsDown, Plus, Calendar, Star, X } from "lucide-react";
import { formatDate, formatRating } from "../../../utils/helpers";
import { VOTE_TYPE } from "../../../utils/constants";

export default function VotesSection({ allVotes, watchHistory, onShowAddUpvote, onShowAddDownvote, onRemoveVote }) {
  const upvotes = allVotes.filter(v => v.vote_type !== VOTE_TYPE.DOWNVOTE);
  const downvotes = allVotes.filter(v => v.vote_type === VOTE_TYPE.DOWNVOTE);

  return (
    <div className="px-4 space-y-5">
      {/* Votes Section */}
      {(upvotes.length > 0 || downvotes.length > 0) && (
        <div>
          <h2 className="text-ios-headline font-semibold text-ios-label mb-3">Recommendations</h2>

          {/* Upvotes */}
          {upvotes.length > 0 && (
            <div className="ios-card mb-3">
              <div className="px-4 py-2 bg-ios-green/10 border-b border-ios-separator flex items-center gap-2">
                <ThumbsUp className="w-4 h-4 text-ios-green" />
                <span className="text-ios-caption1 text-ios-green font-semibold">
                  Recommended by {upvotes.length}
                </span>
              </div>
              <div className="divide-y divide-ios-separator">
                {upvotes.map((vote, idx) => {
                  const person = vote.person_details || { name: vote.person };
                  const avatarBg = person.color || "#30d158";
                  const displayEmoji = person.emoji || person.name?.charAt(0)?.toUpperCase() || "?";
                  return (
                    <div key={idx} className="px-4 py-3 flex items-center gap-3">
                      <div
                        className="w-10 h-10 rounded-full flex items-center justify-center text-base font-semibold text-white flex-shrink-0"
                        style={{ backgroundColor: avatarBg }}
                      >
                        {displayEmoji}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-ios-body text-ios-label font-medium">{vote.person}</p>
                        {vote.date_recommended && (
                          <p className="text-ios-caption1 text-ios-tertiary-label">
                            {formatDate(vote.date_recommended * 1000)}
                          </p>
                        )}
                      </div>
                      <div className="flex items-center gap-2">
                        {vote.vote_type === VOTE_TYPE.STRONG_RECOMMEND && (
                          <span className="text-ios-caption2 text-ios-green bg-ios-green/10 px-2 py-0.5 rounded-full font-medium">
                            Strong
                          </span>
                        )}
                        <button
                          onClick={() => onRemoveVote(vote.person)}
                          className="p-1.5 rounded-full hover:bg-ios-fill-tertiary active:bg-ios-fill-quaternary transition-colors"
                          title="Remove recommendation"
                        >
                          <X className="w-4 h-4 text-ios-tertiary-label" />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Downvotes */}
          {downvotes.length > 0 && (
            <div className="ios-card mb-3">
              <div className="px-4 py-2 bg-ios-red/10 border-b border-ios-separator flex items-center gap-2">
                <ThumbsDown className="w-4 h-4 text-ios-red" />
                <span className="text-ios-caption1 text-ios-red font-semibold">
                  Not Recommended by {downvotes.length}
                </span>
              </div>
              <div className="divide-y divide-ios-separator">
                {downvotes.map((vote, idx) => {
                  const person = vote.person_details || { name: vote.person };
                  const avatarBg = person.color || "#ff453a";
                  const displayEmoji = person.emoji || person.name?.charAt(0)?.toUpperCase() || "?";
                  return (
                    <div key={idx} className="px-4 py-3 flex items-center gap-3">
                      <div
                        className="w-10 h-10 rounded-full flex items-center justify-center text-base font-semibold text-white flex-shrink-0"
                        style={{ backgroundColor: avatarBg }}
                      >
                        {displayEmoji}
                      </div>
                      <div className="flex-1 min-w-0">
                        <p className="text-ios-body text-ios-label font-medium">{vote.person}</p>
                        {vote.date_recommended && (
                          <p className="text-ios-caption1 text-ios-tertiary-label">
                            {formatDate(vote.date_recommended * 1000)}
                          </p>
                        )}
                      </div>
                      <button
                        onClick={() => onRemoveVote(vote.person)}
                        className="p-1.5 rounded-full hover:bg-ios-fill-tertiary active:bg-ios-fill-quaternary transition-colors flex-shrink-0"
                        title="Remove downvote"
                      >
                        <X className="w-4 h-4 text-ios-tertiary-label" />
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Add Upvote Button */}
          <button
            onClick={onShowAddUpvote}
            className="w-full ios-card px-4 py-3 flex items-center justify-center gap-2 text-ios-green active:bg-ios-fill-tertiary transition-colors mb-2"
          >
            <Plus className="w-5 h-5" />
            <span className="font-medium">Add Recommendation</span>
          </button>

          {/* Add Downvote Button */}
          <button
            onClick={onShowAddDownvote}
            className="w-full ios-card px-4 py-3 flex items-center justify-center gap-2 text-ios-red active:bg-ios-fill-tertiary transition-colors"
          >
            <Plus className="w-5 h-5" />
            <span className="font-medium">Add Someone Who Didn't Like It</span>
          </button>
        </div>
      )}

      {/* Watch History */}
      {watchHistory && (
        <div>
          <h2 className="text-ios-headline font-semibold text-ios-label mb-3">Watch History</h2>
          <div className="ios-card px-4 py-3">
            <div className="flex items-center justify-between text-ios-body text-ios-label">
              <span className="flex items-center gap-1">
                <Calendar className="w-4 h-4" />
                {formatDate(watchHistory.dateWatched)}
              </span>
              <span className="flex items-center gap-1 text-ios-yellow font-medium">
                <Star className="w-4 h-4 fill-current" />
                Rated {formatRating(watchHistory.myRating)}/10
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
