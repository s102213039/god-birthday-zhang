class CandidatesController < ApplicationController
  before_action :find_candidate, only: [:edit, :update, :destroy, :vote, :show]

  
  def index 
    @candidates = Candidate.all.order(:id)
  end

  def new
    @candidate = Candidate.new
  end
  
  def show
  end
  
  def vote
    @candidate.increment(:votes)
    @candidate.save
    redirect_to candidates_path, notice: "完成投票!"
  end
  
  def create
    @candidate = Candidate.new(candidate_params)
    
    if @candidate.save
      # 成功
      redirect_to candidates_path, notice: "新增候選人成功!"
    else
      # 失敗
      render :new
    end
  end
  
  def edit
  end
  
  def update    
    if @candidate.update_attributes(candidate_params)
      # 成功
      redirect_to candidates_path, notice: "資料更新成功!"
    else
      #失敗
      render :edit
    end
  end
  
  def destroy
    @candidate.destroy if @candidate
    redirect_to candidates_path, notice: "候選人資料已刪除!"
  end
  
  private
  def candidate_params
    params.require(:candidate).permit(:name, :age, :party, :politics )
  end
  
  def find_candidate
    @candidate = Candidate.find_by(id: params[:id])
  end
end
