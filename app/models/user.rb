class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
           # matches THIS user initiated
  has_many :matches, dependent: :destroy

  # all Users this user swiped on
  has_many :swiped_users,
           through: :matches,
           source: :target
end
