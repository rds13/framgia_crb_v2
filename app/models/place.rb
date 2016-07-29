class Place < ActiveRecord::Base
  belongs_to :user

  validates :name, presence: true

  scope :search_name, ->(name, user_id){where "name LIKE '%#{name}%'
    AND user_id = #{user_id} OR user_id is null"}
  scope :search_address, ->address{where "address LIKE '%#{address}%'"}
  scope :order_by_name, ->{order name: :asc}
  scope :order_by_address, ->{order address: :asc}

  class << self
    def existed_place? place
      Place.pluck(:name).include? place
    end
  end
end