require 'test_helper'

class PregnancyTest < ActiveSupport::TestCase
  before do
    @user = create :user
    @pt_1 = create :patient, name: 'Susan Smith', primary_phone: '123-456-6789'
    @pt_2 = create :patient, name: 'Susan E', primary_phone: '123-456-6789'
    @pt_3 = create :patient, name: 'Susan All', other_phone: '999-999-9999'
    [@pt_1, @pt_2, @pt_3].each do |pt|
      create :pregnancy, patient: pt, created_by: @user
    end
    @pregnancy = @pt_1.pregnancies.first
  end

  describe 'validations' do
    it 'should be able to build an object' do
      assert @pregnancy.valid?
    end

    %w(initial_call_date created_by).each do |field|
      it "should enforce presence of #{field}" do
        @pregnancy[field.to_sym] = nil
        refute @pregnancy.valid?
      end
    end

    it 'should require appointment_date to be after initial_call_date' do
      @pregnancy.initial_call_date = '2016-06-01'
      @pregnancy.appointment_date = '2016-05-01'
      refute @pregnancy.valid?
      @pregnancy.appointment_date = nil
      assert @pregnancy.valid?
      @pregnancy.appointment_date = '2016-07-01'
      assert @pregnancy.valid?
    end
  end

  describe 'methods' do
    describe 'pledge_identifier method' do
      it 'should return a pledge_identifier' do
        @pregnancy.line = 'DC'
        @pregnancy.patient.update primary_phone: '111-333-5555'
        assert_equal 'D3-5555', @pregnancy.pledge_identifier # make it live after merging that one PR
      end
    end

    describe 'most_recent_note_display_text method' do
      before do
        @note = create :note, pregnancy: @pregnancy, full_text: (1..100).map(&:to_s).join('')
      end

      it 'returns 44 characters of the notes text' do
        assert_equal 44, @pregnancy.most_recent_note_display_text.length
        assert_match /^1234/, @pregnancy.most_recent_note_display_text
      end
    end

    describe 'status method' do
      it 'should default to "No Contact Made" when a pregnancy has no calls' do
        assert_equal Pregnancy::STATUSES[:no_contact], @pregnancy.status
      end

      it 'should default to "No Contact Made" on a pregnancy left voicemail' do
        create :call, pregnancy: @pregnancy, status: 'Left voicemail'
        assert_equal Pregnancy::STATUSES[:no_contact], @pregnancy.status
      end

      it 'should update to "Needs Appointment" once patient has been reached' do
        create :call, pregnancy: @pregnancy, status: 'Reached patient'
        assert_equal Pregnancy::STATUSES[:needs_appt], @pregnancy.status
      end

      it 'should update to "Fundraising" once an appointment has been made' do
        @pregnancy.appointment_date = '01/01/2017'
        assert_equal Pregnancy::STATUSES[:fundraising], @pregnancy.status
      end

      it 'should update to "Sent Pledge" after a pledge has been sent' do
        @pregnancy.pledge_sent = true
        assert_equal Pregnancy::STATUSES[:pledge_sent], @pregnancy.status
      end

      # it 'should update to "Pledge Paid" after a pledge has been paid' do
      # end

      it 'should update to "Resolved Without DCAF" if pregnancy is resolved' do
        @pregnancy.resolved_without_dcaf = true
        assert_equal Pregnancy::STATUSES[:resolved], @pregnancy.status
      end
    end

    describe 'contact_made? method' do
      it 'should return false if no calls have been made' do
        refute @pregnancy.send :contact_made?
      end

      it 'should return false if an unsuccessful call has been made' do
        create :call, pregnancy: @pregnancy, status: 'Left voicemail'
        refute @pregnancy.send :contact_made?
      end

      it 'should return true if a successful call has been made' do
        create :call, pregnancy: @pregnancy, status: 'Reached patient'
        assert @pregnancy.send :contact_made?
      end
    end

    describe 'mongoid attachments' do
      it 'should have timestamps from Mongoid::Timestamps' do
        [:created_at, :updated_at].each do |field|
          assert @pregnancy.respond_to? field
          assert @pregnancy[field]
        end
      end

      it 'should respond to history methods' do
        assert @pregnancy.respond_to? :history_tracks
        assert @pregnancy.history_tracks.count > 0
      end

      it 'should have accessible userstamp methods' do
        assert @pregnancy.respond_to? :created_by
        assert @pregnancy.created_by
      end
    end
  end
end
