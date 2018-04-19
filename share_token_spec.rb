require 'spec_helper'

describe ShareToken do

  let(:user) { FactoryGirl.create(:user) }
  let(:music_session) {FactoryGirl.create(:active_music_session) }
  let(:claimed_recording) {FactoryGirl.create(:claimed_recording) }

  before(:each) do
    ShareToken.delete_all
  end

  it "can reference a music session" do
    music_session.touch # should create a MSH, and a token, too
    ShareToken.count.should == 1
    music_session.music_session.share_token.should_not be_nil
    token = ShareToken.find_by_shareable_id!(music_session.id)
    token.should == music_session.music_session.share_token
    token.shareable_id.should == music_session.id
    token.shareable_type.should == 'session'
  end

  it "can reference a claimed recording" do
    claimed_recording.touch # should create a share token
    ShareToken.count.should == 2 # one for MSH, one for recording
    claimed_recording.share_token.should_not be_nil
    token = ShareToken.find_by_shareable_id!(claimed_recording.id)
    claimed_recording.share_token.should == token
    token.shareable_type.should == 'recording'
  end

end
