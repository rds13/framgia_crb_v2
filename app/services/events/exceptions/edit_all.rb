module Events
  module Exceptions
    class EditAll
      def initialize event, params
        @event = event
        @params = params
        @parent = @event.parent.present? ? @event.parent : @event
        @temp_event = Event.new event_params.merge({
          notification_events_attributes: [],
          repeat_ons_attributes: []
        })
      end

      def perform
        return false if changed_start_repeat?
        return false if @temp_event.end_repeat < @parent.start_repeat

        begin
          ActiveRecord::Base.transaction do
            temp_event = Event.new start_date: @params[:start_time_before_change], finish_date: @params[:finish_time_before_change]

            if changed_repeat_type?
              @parent.event_exceptions.each{|event| event.destroy!}

              if @params[:specific_form] == 1
                make_and_assign_attendees @parent
                make_and_assign_notifications @parent
              end

              if temp_event.start_date == @parent.start_date
                update_params = event_params.merge({
                  exception_time: nil, exception_type: nil,
                  start_repeat: @parent.start_repeat, notification_events_attributes: []
                })
              else
                update_params = event_params.merge({
                  exception_time: nil, exception_type: nil,
                  start_date: @parent.start_date, finish_date: @parent.finish_date,
                  start_repeat: @parent.start_repeat, notification_events_attributes: []
                })
              end
              @parent.update_attributes! update_params
            else
              # TÌm thằng gốc và update thông tin cho nó
              if @params[:specific_form] == 1
                make_and_assign_attendees @parent
                make_and_assign_notifications @parent
              end

              if temp_event.start_date == @parent.start_date
                update_params = event_params.merge({
                  exception_time: nil, exception_type: nil,
                  notification_events_attributes: []
                })
              else
                update_params = event_params.merge({
                  exception_time: nil, exception_type: nil,
                  start_date: @parent.start_date, finish_date: @parent.finish_date,
                  start_repeat: @parent.start_repeat, notification_events_attributes: []
                })
              end

              @parent.update_attributes! update_params

              # TÌm tất cả những thằng có excepton không phải là delete và update thêm thông tin cho nó
              @parent.event_exceptions.not_delete_only.each do |event|
                if @params[:specific_form] == 1
                  make_and_assign_attendees event
                  make_and_assign_notifications event
                end
                event.assign_attributes title: @parent.title, description: @parent.description
                event.save!
              end
            end
          end
        rescue ActiveRecord::RecordInvalid => exception
          Rails.logger.info('----------------------> ERRORS!!!!')
        end
      end

      private

      def event_params
        @params.require(:event).permit Event::ATTRIBUTES_PARAMS
      end

      def changed_repeat_type?
        return false if @temp_event.repeat_type.nil?
        @temp_event.repeat_type != @parent.repeat_type
      end

      def changed_start_repeat?
        @temp_event.start_repeat.to_date != @temp_event.start_date.to_date
      end

      def attendee_emails
        return [] if @params[:attendee].blank?
        return @params[:attendee][:emails]
      end

      def make_and_assign_attendees event
        users = User.where(email: attendee_emails).select(:email, :id)
        attendees = Attendee.where(email: attendee_emails)
        emails = users.map(&:email) + attendees.map(&:email)

        users.each do |user|
          attendees += [Attendee.find_or_initialize_by(user_id: user.id)]
        end

        attendee_emails.each do |email|
          next if emails.include?(email)
          attendees += [Attendee.new(email: email)]
        end

        if event.parent? && event.is_repeat?
          @attendees_will_delete = event.attendees.to_a - attendees.uniq
        elsif event.parent.present?
          attendees_will_delete = @attendees_will_delete || []
          attendees_will_add = event.attendees + attendees - attendees_will_delete
          return event.attendees = attendees_will_add
        end

        event.attendees = attendees.uniq
      end

      def make_and_assign_notifications event
        temp_event = Event.new event_params.merge({
          repeat_ons_attributes: []
        })
        event.notification_events = temp_event.notification_events
      end
    end
  end
end
