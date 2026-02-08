import { LogOut } from "lucide-react";
import UserStats from "../components/UserStats";

export default function AccountPage({ movies, user, logout }) {
  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between gap-4 pt-2">
        <div>
          <h2 className="text-ios-title1">Account</h2>
          <p className="text-ios-caption1 text-ios-secondary-label mt-1">{user?.username}</p>
        </div>
      </div>

      <div className="ios-card p-5 space-y-4">
        <div>
          <p className="text-ios-caption1 text-ios-secondary-label uppercase tracking-wider">Username</p>
          <p className="text-ios-headline text-ios-label mt-1">{user?.username}</p>
        </div>
        {user?.email && (
          <div>
            <p className="text-ios-caption1 text-ios-secondary-label uppercase tracking-wider">Email</p>
            <p className="text-ios-body text-ios-label mt-1 break-all">{user.email}</p>
          </div>
        )}
        <button onClick={logout} className="btn-ios-secondary w-full justify-center">
          <LogOut className="w-4 h-4 mr-2" />
          Logout
        </button>
      </div>

      <UserStats movies={movies} user={user} showHeader={false} showUserCard={false} />
    </div>
  );
}
