# frozen_string_literal: true

class AddYetAnotherColorToShirts < ActiveRecord::Migration[6.1]
  def up
    Alterity.disable do
      add_column :shirts, :color3, :string
    end
  end
end
