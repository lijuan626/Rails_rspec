require 'spec_helper'

describe ActiveMusicSession do

  before(:each) do
    ActiveMusicSession.delete_all
    IcecastServer.delete_all
    IcecastMount.delete_all
  end

  it 'can grant access to valid user' do

    user1 = FactoryGirl.create(:user) # in the jam session
    user2 = FactoryGirl.create(:user) # in the jam session
    user3 = FactoryGirl.create(:user) # not in the jam session

    music_session = FactoryGirl.create(:active_music_session, :creator => user1, :musician_access => false)
    FactoryGirl.create(:connection, :user => user1, :music_session => music_session)
    FactoryGirl.create(:connection, :user => user2, :music_session => music_session)


    music_session.access?(user1).should == true
    music_session.access?(user2).should == true
    music_session.access?(user3).should == false
  end

  it 'anyone can join a open music session' do

    user1 = FactoryGirl.create(:user) # in the jam session
    user2 = FactoryGirl.create(:user) # in the jam session
    user3 = FactoryGirl.create(:user) # not in the jam session

    music_session = FactoryGirl.create(:active_music_session, :creator => user1, :musician_access => true)

    music_session.can_join?(user1, true).should == true
    music_session.can_join?(user2, true).should == true
    music_session.can_join?(user3, true).should == true
  end

  it 'no one but invited people can join closed music session' do
    user1 = FactoryGirl.create(:user) # in the jam session
    user2 = FactoryGirl.create(:user) # in the jam session
    user3 = FactoryGirl.create(:user) # not in the jam session

    music_session = FactoryGirl.create(:active_music_session, :creator => user1, :musician_access => false)
    FactoryGirl.create(:connection, :user => user1, :music_session => music_session)

    music_session.can_join?(user1, true).should == true
    music_session.can_join?(user2, true).should == false
    music_session.can_join?(user3, true).should == false

    # invite user 2
    FactoryGirl.create(:friendship, :user => user1, :friend => user2)
    FactoryGirl.create(:friendship, :user => user2, :friend => user1)
    FactoryGirl.create(:invitation, :sender => user1, :receiver => user2, :music_session => music_session.music_session)

    music_session.can_join?(user1, true).should == true
    music_session.can_join?(user2, true).should == true
    music_session.can_join?(user3, true).should == false
  end

  it 'no one but invited people can see closed music session' do
    user1 = FactoryGirl.create(:user) # in the jam session
    user2 = FactoryGirl.create(:user) # in the jam session
    user3 = FactoryGirl.create(:user) # not in the jam session

    music_session = FactoryGirl.create(:active_music_session, :creator => user1, :musician_access => false, :fan_access => false)
    FactoryGirl.create(:connection, :user => user1, :music_session => music_session)

    music_session.can_see?(user1).should == true
    music_session.can_see?(user2).should == false
    music_session.can_see?(user3).should == false

    # invite user 2
    FactoryGirl.create(:friendship, :user => user1, :friend => user2)
    FactoryGirl.create(:friendship, :user => user2, :friend => user1)
    FactoryGirl.create(:invitation, :sender => user1, :receiver => user2, :music_session => music_session.music_session)

    music_session.can_see?(user1).should == true
    music_session.can_see?(user2).should == true
    music_session.can_see?(user3).should == false
  end

  describe "index" do
    it "orders two sessions by created_at starting with most recent" do
      creator = FactoryGirl.create(:user)
      creator2 = FactoryGirl.create(:user)

      earlier_session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Earlier Session")
      FactoryGirl.create(:connection, :user => creator, :music_session => earlier_session)

      later_session = FactoryGirl.create(:active_music_session, :creator => creator2, :description => "Later Session")
      FactoryGirl.create(:connection, :user => creator2, :music_session => later_session)

      user = FactoryGirl.create(:user)

      #ActiveRecord::Base.logger = Logger.new(STDOUT)
      music_sessions = ActiveMusicSession.index(user)
      music_sessions.length.should == 2
      music_sessions.first.id.should == later_session.id
    end

    it "orders sessions with inviteds first, even if created first" do
      creator1 = FactoryGirl.create(:user)
      creator2 = FactoryGirl.create(:user)

      earlier_session = FactoryGirl.create(:active_music_session, :creator => creator1, :description => "Earlier Session")
      FactoryGirl.create(:connection, :user => creator1, :music_session => earlier_session)
      later_session = FactoryGirl.create(:active_music_session, :creator => creator2, :description => "Later Session")
      FactoryGirl.create(:connection, :user => creator2, :music_session => later_session)
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:connection, :user => creator1, :music_session => earlier_session)
      FactoryGirl.create(:friendship, :user => creator1, :friend => user)
      FactoryGirl.create(:friendship, :user => user, :friend => creator1)
      FactoryGirl.create(:invitation, :sender => creator1, :receiver => user, :music_session => earlier_session.music_session)

      music_sessions = ActiveMusicSession.index(user)
      music_sessions.length.should == 2
      music_sessions.first.id.should == earlier_session.id
    end


    it "orders sessions with friends in the session first, even if created first" do

      creator1 = FactoryGirl.create(:user)
      creator2 = FactoryGirl.create(:user)
      earlier_session = FactoryGirl.create(:active_music_session, :creator => creator1, :description => "Earlier Session")
      FactoryGirl.create(:connection, :user => creator1, :music_session => earlier_session)
      later_session = FactoryGirl.create(:active_music_session, :creator => creator2, :description => "Later Session")
      FactoryGirl.create(:connection, :user => creator2, :music_session => later_session)

      user = FactoryGirl.create(:user)
      FactoryGirl.create(:friendship, :user => creator1, :friend => user)
      FactoryGirl.create(:friendship, :user => user, :friend => creator1)
      FactoryGirl.create(:connection, :user => creator1, :music_session => earlier_session)
      FactoryGirl.create(:connection, :user => creator2, :music_session => earlier_session)

      music_sessions = ActiveMusicSession.index(user)
      music_sessions.length.should == 2
      music_sessions.first.id.should == earlier_session.id
    end

    it "doesn't list a session if musician_access is set to false" do
      creator = FactoryGirl.create(:user)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session", :musician_access => false)
      user = FactoryGirl.create(:user)

      music_sessions = ActiveMusicSession.index(user)
      music_sessions.length.should == 0
    end

    it "does list a session if musician_access is set to false but user was invited" do
      creator = FactoryGirl.create(:user)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session", :musician_access => false)
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:connection, :user => creator, :music_session => session)
      FactoryGirl.create(:friendship, :user => creator, :friend => user)
      FactoryGirl.create(:friendship, :user => user, :friend => creator)
      FactoryGirl.create(:invitation, :sender => creator, :receiver => user, :music_session => session.music_session)

      music_sessions = ActiveMusicSession.index(user)
      music_sessions.length.should == 1
    end

    it "lists a session if the genre matches" do
      creator = FactoryGirl.create(:user)
      genre = FactoryGirl.create(:genre)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session", :genre => genre)
      FactoryGirl.create(:connection, :user => creator, :music_session => session)
      user = FactoryGirl.create(:user)

      music_sessions = ActiveMusicSession.index(user, genres: [genre.id])
      music_sessions.length.should == 1
    end

    it "does not list a session if the genre fails to match" do
      creator = FactoryGirl.create(:user)
      genre1 = FactoryGirl.create(:genre)
      genre2 = FactoryGirl.create(:genre)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session", :genre => genre1)
      user = FactoryGirl.create(:user)

      music_sessions = ActiveMusicSession.index(user, genres: [genre2.id])
      music_sessions.length.should == 0
    end

    it "does not list a session if friends_only is set and no friends are in it" do
      creator = FactoryGirl.create(:user)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session")
      user = FactoryGirl.create(:user)

      music_sessions = ActiveMusicSession.index(user, friends_only: true)
      music_sessions.length.should == 0
    end

    it "lists a session properly if a friend is in it" do
      creator = FactoryGirl.create(:user)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session")
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:friendship, :user => creator, :friend => user)
      FactoryGirl.create(:friendship, :user => user, :friend => creator)
      FactoryGirl.create(:connection, :user => creator, :music_session => session)

      music_sessions = ActiveMusicSession.index(user)
      music_sessions.length.should == 1
      music_sessions = ActiveMusicSession.index(user, friends_only: true)
      music_sessions.length.should == 1
      music_sessions = ActiveMusicSession.index(user, friends_only: false, my_bands_only: true)
      music_sessions.length.should == 0
      music_sessions = ActiveMusicSession.index(user, friends_only: true, my_bands_only: true)
      music_sessions.length.should == 1
    end

    it "does not list a session if it has no participants" do
      # it's a design goal that there should be no sessions with 0 connections;
      # however, this bug continually crops up so the .index method will protect against this common bug

      creator = FactoryGirl.create(:user)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session")
      session.connections.delete_all # should leave a bogus, 0 participant session around

      music_sessions = ActiveMusicSession.index(creator)
      music_sessions.length.should == 0

    end

    it "does not list a session if my_bands_only is set and it's not my band" do
      creator = FactoryGirl.create(:user)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session")
      user = FactoryGirl.create(:user)

      music_sessions = ActiveMusicSession.index(user, friends_only: false, my_bands_only: true)
      music_sessions.length.should == 0
    end

    it "lists a session properly if it's my band's session" do
      band = FactoryGirl.create(:band)
      creator = FactoryGirl.create(:user)
      session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Session", :band => band)
      FactoryGirl.create(:connection, :user => creator, :music_session => session)
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:band_musician, :band => band, :user => creator)
      FactoryGirl.create(:band_musician, :band => band, :user => user)

      music_sessions = ActiveMusicSession.index(user)
      music_sessions.length.should == 1
      music_sessions = ActiveMusicSession.index(user, friends_only: true)
      music_sessions.length.should == 0
      music_sessions = ActiveMusicSession.index(user, friends_only: false, my_bands_only: true)
      music_sessions.length.should == 1
      music_sessions = ActiveMusicSession.index(user, friends_only: true, my_bands_only: true)
      music_sessions.length.should == 1
    end

    describe "index(as_musician: false)" do
      let(:fan_access) { true }
      let(:creator) { FactoryGirl.create(:user) }
      let(:session) { FactoryGirl.create(:active_music_session, creator: creator, fan_access: fan_access ) }
      let(:connection) { FactoryGirl.create(:connection, user: creator, :music_session => session) }

      let(:user) {FactoryGirl.create(:user) }

      describe "no mount" do

        before(:each) do
          session.mount.should be_nil
        end

        it "no session listed if mount is nil" do
          connection.touch
          sessions = ActiveMusicSession.index(user, as_musician: false)
          sessions.length.should == 0
        end
      end

      describe "with mount" do
        let(:session_with_mount) { FactoryGirl.create(:active_music_session_with_mount) }
        let(:connection_with_mount) { FactoryGirl.create(:connection, user: creator, :music_session => session_with_mount) }


        before(:each) {
          session_with_mount.mount.should_not be_nil
        }

        it "no session listed if icecast_server config hasn't been updated" do
          connection_with_mount.touch
          sessions = ActiveMusicSession.index(user, as_musician: false)
          sessions.length.should == 0
        end

        it "session listed if icecast_server config has been updated" do
          connection_with_mount.touch
          session_with_mount.created_at = 2.minutes.ago
          session_with_mount.save!(:validate => false)
          session_with_mount.mount.server.config_updated_at = 1.minute.ago
          session_with_mount.mount.server.save!(:validate => false)
          sessions = ActiveMusicSession.index(user, as_musician: false)
          sessions.length.should == 1
        end
      end

    end
  end

  describe "nindex" do
    it "nindex orders two sessions by created_at starting with most recent" do
      creator = FactoryGirl.create(:user)
      creator2 = FactoryGirl.create(:user)

      earlier_session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Earlier Session")
      c1 = FactoryGirl.create(:connection, user: creator, music_session: earlier_session, addr: 0x01020304, locidispid: 1)

      later_session = FactoryGirl.create(:active_music_session, :creator => creator2, :description => "Later Session")
      c2 = FactoryGirl.create(:connection, user: creator2, music_session: later_session, addr: 0x21020304, locidispid: 2)

      user = FactoryGirl.create(:user)
      c3 = FactoryGirl.create(:connection, user: user, locidispid: 3)

      Score.createx(c1.locidispid, c1.client_id, c1.addr, c3.locidispid, c3.client_id, c3.addr, 20, nil);
      Score.createx(c2.locidispid, c2.client_id, c2.addr, c3.locidispid, c3.client_id, c3.addr, 30, nil);

      # scores!

      #ActiveRecord::Base.logger = Logger.new(STDOUT)
      music_sessions = ActiveMusicSession.nindex(user, client_id: c3.client_id).take(100)
      #music_sessions = MusicSession.index(user).take(100)
      #ActiveRecord::Base.logger = nil

      music_sessions.length.should == 2
      music_sessions[0].id.should == later_session.id
      music_sessions[1].id.should == earlier_session.id
    end
  end


  def ams(user, params)
    ActiveRecord::Base.transaction do
      return ActiveMusicSession.ams_index(user, params)
    end
  end

  describe "ams_index", no_transaction: true do
    it "does not crash" do

      creator = FactoryGirl.create(:user, last_jam_locidispid: 1, last_jam_audio_latency: 5)
      creator2 = FactoryGirl.create(:user, last_jam_locidispid: 2, last_jam_audio_latency: 10)

      earlier_session = FactoryGirl.create(:active_music_session, :creator => creator, :description => "Earlier Session")
      c1 = FactoryGirl.create(:connection, user: creator, music_session: earlier_session, locidispid: 1, last_jam_audio_latency: 5)

      later_session = FactoryGirl.create(:active_music_session, :creator => creator2, :description => "Later Session")
      c2 = FactoryGirl.create(:connection, user: creator2, music_session: later_session, locidispid: 2, last_jam_audio_latency: 10)

      user = FactoryGirl.create(:user, last_jam_locidispid: 1, last_jam_audio_latency: 5)
      c3 = FactoryGirl.create(:connection, user: user, locidispid: 1, last_jam_audio_latency: 5)

      Score.createx(c1.locidispid, c1.client_id, c1.addr, c3.locidispid, c3.client_id, c3.addr, 20, nil)
      Score.createx(c2.locidispid, c2.client_id, c2.addr, c3.locidispid, c3.client_id, c3.addr, 30, nil)

      # make a transaction

      ActiveRecord::Base.transaction do

        ActiveMusicSession.ams_init(user, client_id: c3.client_id)

        music_sessions = ActiveMusicSession.ams_query(user, client_id: c3.client_id).take(100)
        music_sessions.should_not be_nil
        music_sessions.length.should == 2
        music_sessions[0].tag.should_not be_nil
        music_sessions[0].latency.should_not be_nil
        music_sessions[1].tag.should_not be_nil
        music_sessions[1].latency.should_not be_nil

        users = ActiveMusicSession.ams_users.take(100)
        users.should_not be_nil
        users.length.should == 2
        if users[0].music_session_id == earlier_session.id
          users[0].id.should == creator.id
          users[0].latency.should == 15 # (5 + 20 + 5) / 2
          users[1].music_session_id == later_session.id
          users[1].id.should == creator2.id
          users[1].latency.should == 22 # (5 + 30 + 10) / 2
        else
          users[0].music_session_id.should == later_session.id
          users[0].id.should == creator2.id
          users[0].latency.should == 22 # (5 + 30 + 10) / 2
          users[1].music_session_id == earlier_session.id
          users[1].id.should == creator.id
          users[1].latency.should == 15 # (5 + 20 + 5) / 2
        end
      end
    end

    describe "parameters" do
      let(:creator_1) { FactoryGirl.create(:user, last_jam_locidispid: 4, last_jam_audio_latency: 8) }
      let(:creator_conn_1) { FactoryGirl.create(:connection, user: creator_1, ip_address: '4.4.4.4', locidispid: 4, addr:4) }
      let(:creator_2) { FactoryGirl.create(:user, last_jam_locidispid: 1, last_jam_audio_latency: 10) }
      let(:creator_conn_2) { FactoryGirl.create(:connection, user: creator_2, ip_address: '4.4.4.4', locidispid: 1, addr:1) }
      let(:creator_3) { FactoryGirl.create(:user, last_jam_locidispid: 2, last_jam_audio_latency: 12) }
      let(:creator_conn_3) { FactoryGirl.create(:connection, user: creator_3, ip_address: '5.5.5.5', locidispid: 2, addr:2) }
      let(:searcher_1) { FactoryGirl.create(:user, last_jam_locidispid: 5, last_jam_audio_latency: 6) }
      let(:searcher_conn_1) { FactoryGirl.create(:connection, user: searcher_1, ip_address: '8.8.8.8', locidispid: 5, addr:5) }
      let(:searcher_2) { FactoryGirl.create(:user, last_jam_locidispid: 3, last_jam_audio_latency: 14) }
      let(:searcher_conn_2) { FactoryGirl.create(:connection, user: searcher_2, ip_address: '9.9.9.9', locidispid: 3, addr:3) }

      let!(:music_session_1) { FactoryGirl.create(:active_music_session, :creator => creator_1, genre: Genre.find('african'), language: 'eng', description: "Bunny Jumps" ) }
      let!(:music_session_2) { FactoryGirl.create(:active_music_session, :creator => creator_2, genre: Genre.find('ambient'), language: 'spa', description: "Play with us as we jam to beatles and bunnies") }

      let(:good_network_score) { 20 }
      let(:fair_network_score) { 30 }
      let(:tracks) { [{'sound' => 'mono', 'client_track_id' => 'abc', 'instrument_id' => 'piano'}] }

      it "offset/limit" do
        # put creators in the session
        creator_conn_1.join_the_session(music_session_1.music_session, true, tracks, creator_1, 10)
        creator_conn_1.errors.any?.should be_false
        creator_conn_2.join_the_session(music_session_2.music_session, true, tracks, creator_2, 10)
        creator_conn_2.errors.any?.should be_false

        # set up some scores to control sorting
        Score.createx(searcher_conn_1.locidispid, searcher_conn_1.client_id, searcher_conn_1.addr, creator_conn_1.locidispid, creator_conn_1.client_id, creator_conn_1.addr, good_network_score, nil)
        Score.createx(searcher_conn_1.locidispid, searcher_conn_1.client_id, searcher_conn_1.addr, creator_conn_2.locidispid, creator_conn_2.client_id, creator_conn_2.addr, fair_network_score, nil)

        # verify we can get all 2 sessions
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id)
        music_sessions.length.should == 2
        music_sessions[0].should == music_session_1.music_session

        # grab just the 1st
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, offset:0, limit:1)
        music_sessions.length.should == 1
        music_sessions[0].should == music_session_1.music_session

        # then the second
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, offset:1, limit:2)
        music_sessions.length.should == 1
        music_sessions[0].should == music_session_2.music_session
      end

      it "genre" do
        # verify we can get all 2 sessions
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id)
        music_sessions.length.should == 2

        # get only african
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, genre: 'african')
        music_sessions.length.should == 1
        music_sessions[0].genre.should == Genre.find('african')

        # get only ambient
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, genre: 'ambient')
        music_sessions.length.should == 1
        music_sessions[0].genre.should == Genre.find('ambient')
      end

      it "language" do
        # verify we can get all 2 sessions
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id)
        music_sessions.length.should == 2

        # get only english
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, lang: 'eng')
        music_sessions.length.should == 1
        music_sessions[0].language.should == 'eng'

        # get only ambient
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, lang: 'spa')
        music_sessions.length.should == 1
        music_sessions[0].language.should == 'spa'
      end

      it "keyword" do
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, keyword: 'Jump')
        music_sessions.length.should == 1
        music_sessions[0].should == music_session_1.music_session

        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, keyword: 'Bunny')
        music_sessions.length.should == 2

        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, keyword: 'play')
        music_sessions.length.should == 1

        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, keyword: 'bun')
        music_sessions.length.should == 2
      end

      it "date" do
        music_session_1.music_session.scheduled_start = 1.days.ago
        music_session_1.music_session.save!

        # if no day/timezone_offset specified, both should be returned
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id)
        music_sessions.length.should == 2

        # find today's session
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, day: Date.today.to_s, timezone_offset: DateTime.now.offset.numerator)
        music_sessions.length.should == 1
        music_sessions[0].should == music_session_2.music_session


        # find yesterday's session
        music_sessions, user_search = ams(searcher_1, client_id: searcher_conn_1.client_id, day: (Date.today - 1).to_s, timezone_offset: DateTime.now.offset.numerator)
        music_sessions.length.should == 1
        music_sessions[0].should == music_session_1.music_session
      end

      it "should allow a null locidispid to search" do
        searcher_conn_1.locidispid = nil
        searcher_conn_1.save!
        music_sessions, user_scores = ams(searcher_1, client_id: searcher_conn_1.client_id)
        music_sessions.length.should == 2

      end
    end

    # todo we need more tests:
    #
    # the easiest collection of tests, not involving filtering, just tagging and latency, still result in many cases
    # (given a creator, member, and observer):
    #
    # {not_rsvp, rsvp_not_chosen, rsvp_chosen} x
    # {not_invited, invited} x
    # {no_musicians, musicians_on_approval, musicians_freely_join} x
    # {creator_not_member, creator_is_member} x
    # {observer_not_member, observer_is_member} x
    # {observer_member_not_scored, observer_member_scored}
    #
    # eh, that's 144 cases all told, and that doesn't cover the cases with multiple members...
    #
    # member is the user in the session
    # creator is the user that created the session
    # observer is the user making the call to ams_index
    #
    # the first two categories (rsvp and invited) are about the observer.
    #
    # i see this being written like this:
    #
    # test_ams([:not_rsvp, :not_invited, :no_musicians, :creator_not_member, :observer_not_member, :observer_member_not_scored],
    #   member_latency, observer_member_score, observer_latency, expected_count, expected_tag, expected_latency)
    #
    # ... repeat as above with all the various combinations by choosing one from each category and appropriate other
    # values and then expected results ...
    #
    # expected_count is 0 for the above written case, and would be 1 in the cases where any of rsvp_chosen, invited,
    # musicians_on_approval, or musicians_freely_join are specified. test_ams would know which session and user should
    # appear in the results of ams_index and ams_users.
    #
    # there should be an additional active music session created and joined by a distinct user, other. it should never
    # appear in results.
  end


  it 'uninvited users cant join approval-required sessions without invitation' do
    user1 = FactoryGirl.create(:user) # in the jam session
    user2 = FactoryGirl.create(:user) # in the jam session

    music_session = FactoryGirl.create(:active_music_session, :creator => user1, :musician_access => true, :approval_required => true)

    connection1 = FactoryGirl.create(:connection, :user => user1, :music_session => music_session)
    expect { FactoryGirl.create(:connection, :user => user2, :music_session => music_session, :joining_session => true) }.to raise_error(ActiveRecord::RecordInvalid)

  end


  it "is_recording? returns false if not recording" do
    user1 = FactoryGirl.create(:user)
    music_session = FactoryGirl.build(:active_music_session, :creator => user1)
    music_session.is_recording?.should be_false
  end

  describe "recordings" do

    before(:each) do
      @user1 = FactoryGirl.create(:user)
      @connection = FactoryGirl.create(:connection, :user => @user1)
      @instrument = FactoryGirl.create(:instrument, :description => 'a great instrument')
      @track = FactoryGirl.create(:track, :connection => @connection, :instrument => @instrument)
      @music_session = FactoryGirl.create(:active_music_session, :creator => @user1, :musician_access => true)
      # @music_session.connections << @connection
      @music_session.save!
      @connection.join_the_session(@music_session, true, nil, @user1, 10)
    end

    describe "not recording" do
      it "stop_recording should return nil if not recording" do
        @music_session.stop_recording.should be_nil
      end
    end

    describe "currently recording" do
       before(:each) do
         @recording = FactoryGirl.create(:recording, :music_session => @music_session, :owner => @user1)
       end

       it "is_recording? returns true if recording" do
         @music_session.is_recording?.should be_true
       end

       it "stop_recording should return recording object if recording" do
         @music_session.stop_recording.should == @recording
       end
    end

    describe "claim a recording" do

      before(:each) do
        @recording = Recording.start(@music_session, @user1)
        @recording.errors.any?.should be_false
        @recording.stop
        @recording.reload
        @claimed_recording = @recording.claim(@user1, "name", "description", Genre.first, true)
        @claimed_recording.errors.any?.should be_false
      end

      it "allow a claimed recording to be associated" do
        @music_session.claimed_recording_start(@user1, @claimed_recording)
        @music_session.errors.any?.should be_false
        @music_session.reload
        @music_session.claimed_recording.should == @claimed_recording
        @music_session.claimed_recording_initiator.should == @user1
      end

      it "allow a claimed recording to be removed" do
        @music_session.claimed_recording_start(@user1, @claimed_recording)
        @music_session.errors.any?.should be_false
        @music_session.claimed_recording_stop
        @music_session.errors.any?.should be_false
        @music_session.reload
        @music_session.claimed_recording.should be_nil
        @music_session.claimed_recording_initiator.should be_nil
      end

      it "disallow a claimed recording to be started when already started by someone else" do
        @user2 = FactoryGirl.create(:user)
        @music_session.claimed_recording_start(@user1, @claimed_recording)
        @music_session.errors.any?.should be_false
        @music_session.claimed_recording_start(@user2, @claimed_recording)
        @music_session.errors.any?.should be_true
        @music_session.errors[:claimed_recording] == [ValidationMessages::CLAIMED_RECORDING_ALREADY_IN_PROGRESS]
      end

      it "allow a claimed recording to be started when already started by self" do
        @user2 = FactoryGirl.create(:user)
        @claimed_recording2 = @recording.claim(@user1, "name", "description", Genre.first, true)
        @music_session.claimed_recording_start(@user1, @claimed_recording)
        @music_session.errors.any?.should be_false
        @music_session.claimed_recording_start(@user1, @claimed_recording2)
        @music_session.errors.any?.should be_false
      end
    end
  end

  describe "updates parent music_session" do
    it "updates needed fields" do
      music_session = FactoryGirl.create(:music_session, scheduled_start: nil)
      active_music_session = FactoryGirl.create(:active_music_session, music_session: music_session)
      music_session.reload
      active_music_session.reload
      music_session.scheduled_start.to_s.should == active_music_session.created_at.to_s
      music_session.active_music_session.should == active_music_session
    end

    it "ignore scheduled_start if already set" do
      yesterday = 1.days.ago
      music_session = FactoryGirl.create(:music_session, scheduled_start: yesterday)
      active_music_session = FactoryGirl.create(:active_music_session, music_session: music_session)
      music_session.reload
      music_session.scheduled_start.should == yesterday
    end
  end

  describe "get_connection_ids" do
    before(:each) do
      @user1 = FactoryGirl.create(:user)
      @user2 = FactoryGirl.create(:user)
      @music_session = FactoryGirl.create(:active_music_session, :creator => @user1, :musician_access => true)
      @connection1 = FactoryGirl.create(:connection, :user => @user1, :music_session => @music_session, :as_musician => true)
      @connection2 = FactoryGirl.create(:connection, :user => @user2, :music_session => @music_session, :as_musician => false)

    end

    it "get all connections" do
      @music_session.get_connection_ids().should == [@connection1.client_id, @connection2.client_id]
    end

    it "exclude non-musicians" do
      @music_session.get_connection_ids(as_musician: true).should == [@connection1.client_id]
    end

    it "exclude musicians" do
      @music_session.get_connection_ids(as_musician: false).should == [@connection2.client_id]
    end

    it "exclude particular client" do
      @music_session.get_connection_ids(exclude_client_id: @connection1.client_id).should == [@connection2.client_id]
    end

    it "exclude particular client and exclude non-musicians" do
      @music_session.get_connection_ids(exclude_client_id: @connection2.client_id, as_musician: true).should == [@connection1.client_id]
    end
  end
end

