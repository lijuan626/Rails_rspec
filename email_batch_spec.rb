require 'spec_helper'

describe EmailBatch do

  after(:each) do
    Timecop.return
  end

  describe 'all users' do
    
    # before { pending }

    let (:email_batch) { FactoryGirl.create(:email_batch) }

    before(:each) do
      BatchMailer.deliveries.clear
    end

    it 'has test emails setup' do

      expect(email_batch.test_emails.present?).to be true
      expect(email_batch.pending?).to be true

      users = email_batch.test_users
      expect(email_batch.test_count).to eq(users.count)
    end
  end

  describe 'new musician' do
    before { pending }

    let (:new_musician_batch) { FactoryGirl.create(:email_batch_new_musician) }

    before(:each) do
      @u1 = FactoryGirl.create(:user, :lat => 37.791649, :lng => -122.394395, :email => 'jonathan@jamkazam.com', :subscribe_email => true, :created_at => Time.now - 3.weeks)
      @u2 = FactoryGirl.create(:user, :lat => 37.791649, :lng => -122.394395, :subscribe_email => true)
      @u3 = FactoryGirl.create(:user, :lat => 37.791649, :lng => -122.394395, :subscribe_email => false, :created_at => Time.now - 3.weeks)
      @u4 = FactoryGirl.create(:user, :lat => 37.791649, :lng => -122.394395, :subscribe_email => true, :created_at => Time.now - 3.weeks)
    end

    it 'find new musicians with good score' do
      new_musician_batch.fetch_recipients do |new_musicians|
        expect(new_musicians.count).to eq(2)
        num = (new_musicians.keys.map(&:id) - [@u1.id, @u4.id]).count
        expect(num).to eq(0)
      end
    end

    it 'cycles through states properly' do
      new_musician_batch.deliver_batch
      expect(UserMailer.deliveries.length).to eq(2)
      new_musician_batch.reload
      expect(new_musician_batch.delivered?).to eq(true)
      expect(new_musician_batch.sent_count).to eq(2)
    end

  end

  context 'user progress' do

    # before { pending }

    def handles_new_users(ebatch, user)
      EmailBatchProgression::NUM_IDX.times { |nn| expect(ebatch.fetch_recipients(nn).count).to eq(0) }

      dd = user.created_at
      EmailBatchProgression::NUM_IDX.times do |idx|
        dd = dd + ebatch.days_past_for_trigger_index(idx).days
        Timecop.travel(dd)
        vals = Array.new(3,0)
        vals[idx] = 1
        EmailBatchProgression::NUM_IDX.times do |nn| 
          expect(ebatch.fetch_recipients(nn).count).to eq(vals[nn])
        end
        ebatch.make_set(user, idx)
        EmailBatchProgression::NUM_IDX.times do |nn| 
          expect(ebatch.fetch_recipients(nn).count).to eq(0)
        end
      end
    end

    def handles_existing_users(ebatch, user)
      vals = [1,0,0]
      3.times { |nn| expect(ebatch.fetch_recipients(nn).count).to eq(vals[nn]) }

      dd = user.created_at + ebatch.days_past_for_trigger_index(0).days
      Timecop.travel(dd)
      ebatch.make_set(user, 0)
      3.times { |nn| expect(ebatch.fetch_recipients(nn).count).to eq(0) }

      dd = dd + ebatch.days_past_for_trigger_index(1).days
      Timecop.travel(dd)
      vals = [0,1,0]
      3.times { |nn| expect(ebatch.fetch_recipients(nn).count).to eq(vals[nn]) }
      ebatch.make_set(user, 1)

      dd = dd + ebatch.days_past_for_trigger_index(2).days
      Timecop.travel(dd)
      expect(ebatch.fetch_recipients(2).count).to eq(1)
      ebatch.make_set(user, 2)
      expect(ebatch.fetch_recipients(2).count).to eq(0)

      dd = dd + 1
      Timecop.travel(dd)
      expect(ebatch.fetch_recipients(2).count).to eq(0)
    end

    def skips_some_days(ebatch, user)
      dd = user.created_at + ebatch.days_past_for_trigger_index(1).days
      Timecop.travel(dd)
      vals = [1,0,0]
      3.times { |nn| expect(ebatch.fetch_recipients(nn).count).to eq(vals[nn]) }
      ebatch.make_set(user, 0)
      2.times { |nn| expect(ebatch.fetch_recipients(nn).count).to eq(0) }

      dd = dd + ebatch.days_past_for_trigger_index(1).days
      Timecop.travel(dd)
      vals = [0,1,0]
      3.times { |nn| expect(ebatch.fetch_recipients(nn).count).to eq(vals[nn]) }
      ebatch.make_set(user, 1)
      expect(ebatch.fetch_recipients(2).count).to eq(0)

      dd = dd + ebatch.days_past_for_trigger_index(2).days
      Timecop.travel(dd)
      vals = [0,0,1]
      3.times { |nn| expect(ebatch.fetch_recipients(nn).count).to eq(vals[nn]) }
      ebatch.make_set(user, 2)
      expect(ebatch.fetch_recipients(2).count).to eq(0)
    end

    def loops_bunch_of_users(ebatch, users)
      expect(ebatch.fetch_recipients(0,5).count).to eq(0)
      dd = users[0].created_at + ebatch.days_past_for_trigger_index(0).days
      Timecop.travel(dd)
      expect(ebatch.fetch_recipients(0,5).count).to eq(users.length)
      users.each { |uu| ebatch.make_set(uu, 0) }
      expect(ebatch.fetch_recipients(0,5).count).to eq(0)
      users.map &:destroy
    end

    def sends_one_email(existing_user, ebatch)
      ProgressMailer.deliveries.clear
      ebatch.deliver_batch
      expect(ProgressMailer.deliveries.length).to eq(1)
    end

    describe 'client_notdl' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :client_notdl) 
      }
      let(:user_) { FactoryGirl.create(:user) }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => Time.now - (2 * batchp.days_past_for_trigger_index(2)).days)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user) }
        loops_bunch_of_users(batchp, users)
      end
    end

    describe 'client_dl_notrun' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :client_dl_notrun) 
      }
      let(:user_) { FactoryGirl.create(:user, :first_downloaded_client_at => Time.now) }
      let(:date_in_past) { Time.now - (2 * batchp.days_past_for_trigger_index(2)).days }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => date_in_past,
                           :first_downloaded_client_at => date_in_past)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user, :first_downloaded_client_at => Time.now) }
        loops_bunch_of_users(batchp, users)
      end
    end

    describe 'client_run_notgear' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :client_run_notgear) 
      }
      let(:user_) { FactoryGirl.create(:user, :first_ran_client_at => Time.now) }
      let(:date_in_past) { Time.now - (2 * batchp.days_past_for_trigger_index(2)).days }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => date_in_past,
                           :first_ran_client_at => date_in_past)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user, :first_ran_client_at => Time.now) }
        loops_bunch_of_users(batchp, users)
      end
    end

    describe 'gear_notsess' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :gear_notsess) 
      }
      let(:user_) { FactoryGirl.create(:user, :first_certified_gear_at => Time.now) }
      let(:date_in_past) { Time.now - (2 * batchp.days_past_for_trigger_index(2)).days }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => date_in_past,
                           :first_certified_gear_at => date_in_past)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user, :first_certified_gear_at => Time.now) }
        loops_bunch_of_users(batchp, users)
      end
    end

    describe 'sess_notgood' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :sess_notgood) 
      }
      let(:user_) { FactoryGirl.create(:user, :first_real_music_session_at => Time.now) }
      let(:date_in_past) { Time.now - (2 * batchp.days_past_for_trigger_index(2)).days }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => date_in_past,
                           :first_real_music_session_at => date_in_past)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user, :first_real_music_session_at => Time.now) }
        loops_bunch_of_users(batchp, users)
      end
    end

    describe 'sess_notrecord' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :sess_notrecord) 
      }
      let(:user_) { FactoryGirl.create(:user, :first_real_music_session_at => Time.now) }
      let(:date_in_past) { Time.now - (2 * batchp.days_past_for_trigger_index(2)).days }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => date_in_past,
                           :first_real_music_session_at => date_in_past)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user, :first_real_music_session_at => Time.now) }
        loops_bunch_of_users(batchp, users)
      end
    end

    describe 'reg_notinvite' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :reg_notinvite) 
      }
      let(:user_) { FactoryGirl.create(:user) }
      let(:date_in_past) { Time.now - (2 * batchp.days_past_for_trigger_index(2)).days }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => date_in_past)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user) }
        loops_bunch_of_users(batchp, users)
      end
    end

    describe 'reg_notconnect' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :reg_notconnect) 
      }
      let(:user_) { FactoryGirl.create(:user) }
      let(:date_in_past) { Time.now - (2 * batchp.days_past_for_trigger_index(2)).days }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => date_in_past)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user) }
        loops_bunch_of_users(batchp, users)
      end
    end

    describe 'reg_notlike' do
      # before { pending }
      let(:batchp) { 
        FactoryGirl.create(:email_batch_progression, :sub_type => :reg_notlike) 
      }
      let(:user_) { FactoryGirl.create(:user) }
      let(:date_in_past) { Time.now - (2 * batchp.days_past_for_trigger_index(2)).days }
      let(:user_existing) { 
        FactoryGirl.create(:user, 
                           :created_at => date_in_past)
      }
      after(:each) do
        batchp.clear_batch_sets!
        Timecop.return
      end
      it 'sends one email' do
        sends_one_email(user_existing, batchp)
      end
      it 'handles new users' do
        handles_new_users(batchp, user_)
      end
      it 'handles existing users' do
        handles_existing_users(batchp, user_existing)
      end
      it 'skips some days' do
        skips_some_days(batchp, user_)
      end
      it 'loops bunch of users' do
        users = []
        3.times { |nn| users << FactoryGirl.create(:user) }
        loops_bunch_of_users(batchp, users)
      end
    end

  end
end
