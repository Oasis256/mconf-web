require "digest/sha1"
class UsersController < ApplicationController
  # Include some methods and set some default filters. 
  # See documentation: CMS::Controller::Agents#included
  include CMS::Controller::Agents
  include CMS::Controller::Authorization
  
  
  # Get the User for member actions
  #before_filter :get_agent, :only => :show
  
  # Filter for activation actions
  before_filter :activation_required, :only => [ :activate, 
  :forgot_password, 
  :reset_password ]
  # Filter for password recovery actions
  before_filter :login_and_pass_auth_required, :only => [ :forgot_password,
  :reset_password ]
  
  before_filter :get_space, :except=>[:activate,:forgot_password,:reset_password]
  
  before_filter :get_cloud
  before_filter :authentication_required, :only => [:edit,:update, :destroy]
  before_filter :user_is_admin, :only=> [:search_users2]
  
  before_filter :edit_user,  :only=> [:show,:edit,:update,:destroy]
  before_filter :space_member, :only=>[:show]
  
  # GET /users
  # GET /users.xml
  
  def index
    if params[:only_space_users]
      session[:current_tab] = "People" 
      session[:current_sub_tab] = ""
      @users = @container.actors
    elsif @space.id==1
      session[:current_tab] = "People" 
      session[:current_sub_tab] = ""
      @users = User.find(:all)
    else
      session[:current_tab] = "Manage" 
      session[:current_sub_tab] = "Users"
      @users = User.find(:all)
    end
    respond_to do |format|
      format.html
      format.xml { render :xml => @users }
    end
  end
  
  # GET /users/1
  # GET /users/1.xml
  
  def show
    
    @user = User.find(params[:id])
  end
  
  # GET /users/new
  # GET /users/new.xml  
  def new
    @agent = self.resource_class.new
    if params[:space_id]!=nil
      #2 options, by email or from application
      if params[:by_email]
        render :template =>'users/by_email'
      elsif params[:from_app]
        render :template =>'users/from_app'
      end
    end
  end
  
  # POST /users
  # POST /users.xml
  
  def create
    if params[:space_id]!=nil
      #2 opciones, from email or from app
      if params[:by_email]
        add_user_by_email (params)
        render :template => 'spaces/invitations_results'
        return
      elsif params[:from_app]
        add_user_from_app (params)
        render :template =>'users/from_app'
        return
      end
    end
      cookies.delete :auth_token
      # protects against session fixation attacks, wreaks havoc with 
      # request forgery protection.
      # uncomment at your own risk
      # reset_session    
      @agent = User.new(params[:agent])
      @agent.openid_identifier = session[:openid_identifier]
      @agent.save!
      tag = params[:tag][:add_tag]    
      @agent.tag_with(tag)
      @mail = @agent.email
      
      @invitation = Invitation.find_all_by_email(@mail)
      if @invitation!= nil
        for invitation in @invitation
          @space_id = invitation.space_id
          space= Space.find(@space_id)
          
          if space.container_performances.create :agent => @agent, :role => CMS::Role.find_by_id(invitation.role_id)
            invitation.destroy
          end
        end
      end
      
      flash[:notice] = "Thanks for signing up!. You have received an email with instruccions in order to activate your account."      
      redirect_back_or_default root_path
    rescue ActiveRecord::RecordInvalid
      render :action => 'new'
  end
  
  #This method returns the user to show the form to edit him
  def edit
    session[:current_sub_tab] = "Edit Account"
    @agent = User.find(params[:id])
    
  end
  
  def clean
    render :update do |page|
      page.replace_html 'search_results', ""
      
    end
  end
  
  # PUT /users/1
  # PUT /users/1.xml
  #this method updates a user
  def update
    @user = User.find(params[:id])
    
    if @user.update_attributes(params[:user]) 
      #now we assign the machines to the user
      if current_user.superuser==true
        @array_resources = params[:resource]
        logger.debug("Array de maquinas es  " + @array_resources.to_s)
        @user.machines = Array.new        
        for machine in Machine.find(:all)
          if @array_resources[machine.name]=="1"
            logger.debug("Machine assign " + machine.name)
            @user.machines << machine              
          end            
        end
      end
      
      @user.save
      tag = params[:tag][:add_tag]    
      @user.tag_with(tag)
      flash[:notice] = 'User was successfully updated.'        
      
      #the superuser will be redirected to list_users
      if current_user.superuser == true
        redirect_to(space_users_path(@space.id))
      else
        redirect_to(space_user_profile_path(@space.id, @user.id)) 
      end
      
    else
      if current_user.superuser == true
        redirect_to(space_users_path(@space.id))
      else
        redirect_to(space_user_profile_path(@space.id, @user.id)) 
      end
      
    end
  end
  
  
  # DELETE /users/1
  # DELETE /users/1.xml  
  def destroy
    if params[:space_id]!=nil
      if params[:remove_from_space]
        remove_user(params)
        render :template =>'users/from_app'
        return
      end
    end
    
    id = params[:id] 
    if id && user = User.find(id)
      user.destroy
      flash[:notice] = "User #{user.login} deleted"
    end
    redirect_to(:action => "index")  
  end
  
=begin    
  #search method that returns the users founded with the query in this space.
  def search_users
    @query = params[:query]
    q1 =  @query 
    @use = User.find_by_contents(q1)
    @users = []
    i = 0
    
    @agen = @container.actors
    
    @use.collect { |user|
      # debugger
      if @agen.include?(user)
        @users << user
      end
    }
    
    
    
    respond_to do |format|   
      format.html {render :template=>'/users/show_space_users'}
      format.js 
      
    end
  end
  
  
  #search method that returns the users founded with the query in all the aplication.
  def search_users2
    @query = params[:query]
    q1 =  @query 
    @users = User.find_by_contents(q1)
    
    respond_to do |format| 
      format.html {render :template=>'/users/index'}
      format.js 
      #format.html 
    end
  end
  
  def reset_search
    q1 =  '*' 
    @users = User.find_by_contents(q1, :lazy=> [:login, :email, :name, :lastname, :organization])
    
    respond_to do |format|        
      format.js {render :template =>"users/search_users2.rjs"}
    end
  end
  
  def clean
    render :update do |page|
      page.replace_html 'adv_search', ""
      
    end
  end
  

  #incluido en el controlador search (action => tag)
  def search_by_tag
    
    @tag = params[:tag]
    # @users = User.tagged_with(@tag)   
    #@user = User.find_by_contents(@tag)
    @users = User.tagged_with(@tag)
    respond_to do |format|        
      format.js 
      #format.html 
    end
  end
=end
  
  
  def organization
    respond_to do |format|
      # format.html 
      format.js   
    end
  end
  
  
  private
  
  
  
  def add_user_from_app (params)
    
    session[:current_sub_tab] = "Add Users from App"
    if params[:users] && params[:user_role]
      if CMS::Role.find_by_name(params[:user_role])
        for user_id in params[:users][:id]
          #let`s check if the performance already exist
          perfor = CMS::Performance.find_by_container_id_and_agent_id(@space.id,user_id, :conditions=>["role_id = ?", CMS::Role.find_by_name(params[:user_role])])
          if perfor==nil
            #if it does not exist we create it
            @space.container_performances.create :agent => User.find(user_id), :role => CMS::Role.find_by_name(params[:user_role])
          end
        end
      else        
        flash[:notice] = 'Role ' + params[:user_role] + ' does not exist.'
      end
      
    end
  end
  
  def remove_user (params)
    if params[:users] && params[:user_role]
      if CMS::Role.find_by_name(params[:user_role])
        for user_id in params[:users][:id]
          #let`s check if the performance exist
          perfor = CMS::Performance.find_by_container_id_and_agent_id(@space.id,params[:users][:id], :conditions=>["role_id = ?", CMS::Role.find_by_name(params[:user_role])])
          if perfor
            #if it exists we remove it
            @space.container_performances.delete perfor
          end
        end
      end     
    end
  end
  
  def add_user_by_email  (params)
    #parsear string de emails y hacer todo lo de abajo para cada email.
    session[:current_sub_tab] = "Add Users by email"
    if params[:invitation] && params[:user_role]
      
      if params[:invitation][:email]== ""
        flash[:notice] = "Please insert something in the box"      
        redirect_to  add_user_path
      else
        @parse_email = /^([a-zA-Z0-9_\-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([a-zA-Z0-9\-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/
        @em = params[:invitation][:email]      
        @emails =parse_emails(@em)             
        @role = CMS::Role.find_by_name(params[:user_role])
        params[:invitation][:space_id]= params[:space_id]
        params[:invitation][:user_id]= current_user.id
        params[:invitation][:role_id]= @role.id
        @sp = params[:space_id]
        @space_required = Space.find(@sp)
        @users_invited= []
        @users_added = []
        @users_not_added = []
        @emails_invalid = []
        for email in @emails
          
          @p = /\S+@\S+\.\S+/
          @mail = @p.match(email).to_s
          
          
          @mail = @mail.gsub(/>/,' ')
          @mail = @mail.gsub(/</,' ')
          @mail = @p.match(@mail).to_s
          
          if  @parse_email.match(@mail)!= nil
            params[:invitation][:email]= @mail
            @user = User.find_by_email(@mail)
            if @user
              @perfor = CMS::Performance.find_by_container_id_and_agent_id(params[:space_id],@user.id)
            end
            if @user == nil 
              #falta notificar por mail
              @inv = Invitation.new(params[:invitation])        
              @inv.save! 
              @users_invited << @inv.email
            elsif  @perfor == nil
              @space_required.container_performances.create :agent => @user, :role => CMS::Role.find_by_name(params[:user_role])
              #esta en el sir pero no en el espacio, no añado a la tabla le añado al espacio y le notifico pro mail
              @users_added << @user.email
              #falta notificar por mail
            else
              #el usuraio ya esta en el esapcio
              @users_not_added << @user.email
            end
          else
            @emails_invalid << email          
          end
          
        end
=begin        
        respond_to do |format|
          flash[:notice] = "Users were succesfully invited to the space #{@space_required.name}. An email has been sended to them"
          
          format.html { render :template => '/spaces/invitations_results' }
          format.xml  { head :ok }        
        end
=end        
      end 
    end
  end

  
  #method to parse the request for update from the server that contains
  #<div id=d1>ebarra</div><div id=d2>user2</div>...
  #returns an array with the user logins
  def parse_emails(emails)
    
    return [] if emails.blank?
    emails = Array(emails).first
    emails = emails.respond_to?(:flatten) ? emails.flatten : emails.split(Invitation::DELIMITER)
    emails.map { |email| email.strip.squeeze(" ") }.flatten.compact.map(&:downcase).uniq
    
  end
  
  def edit_user
    
    @agent = @user = User.find(params[:id])
    if current_user.superuser == true 
      return true
      
    elsif current_user.id == @user.id
      return true
    else
      flash[:notice] = "Action not allowed."          
      redirect_to root_path   
    end
  end
  
end
