class HomesController < ApplicationController
  def index
    @research_themes = ResearchTheme.all
  end
end
