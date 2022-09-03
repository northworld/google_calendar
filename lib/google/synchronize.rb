module Google
  class Synchronize
    #
    # Convenience method used to build a hash for incremental sync.
    # Includes events from a Google feed plus necessary synchronization tokens.
    #
    def self.synchronize_hash(response, calendar)
      events = Event.build_from_google_feed(response, calendar)
      unless events.empty?
        events = events.length > 1 ? events : events[0]
      end
      result = { events: events }
      result[:next_sync_token] = response['nextSyncToken'] if response['nextSyncToken']
      result[:next_page_token] = response['nextPageToken'] if response['nextPageToken']
      
      return result
    end
  end
end