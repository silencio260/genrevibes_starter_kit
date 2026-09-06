# genrevibes_remote_config_shared_preferences

Optional cross-launch implementation of `RemoteConfigCache`. Keeping it in a
separate package prevents `shared_preferences` and its platform plugins from
affecting apps that rely only on provider persistence or another storage layer.
