# coding: utf-8
require 'csv'

class Site < Sinatra::Base
  get '/company/register' do
    raise InviteRequired.new('Регистрация только по приглашениям') if session[:invite].nil?
    slim :'company/register'
  end

  post '/company/register' do
    raise InviteRequired.new('Регистрация только по приглашениям') if session[:invite].nil?
    invite = Invite.first(:code => session[:invite])
    raise InviteRequired.new('Приглашение уже было использовано ранее') unless invite.invitee.nil?

    identity = Identity.create email: params[:auth_key], password: params[:password], :role => 'customer', :name => params[:name]
    company = Company.create name: params[:company], :identity => identity

    invite.update(invitee: identity)
    session[:invite] = nil

    session[:user_id] = identity.id
    flash[:info] = "Добро пожаловать!"
    redirect '/company'
  end

  get '/company' do
    authorize! :view, Company
    company = current_identity.company
    slim :'company/index', locals: {company: company}
  end

  get '/company/instructions' do
    authorize! :view, Company
    company = current_identity.company
    slim :'company/instructions', locals: {company: company}
  end

  post '/company/instructions' do
    authorize! :edit, Company
    company = current_identity.company
    company.instructions = params[:text]
    company.save

    redirect '/company'
  end

  get '/company/targets' do
    authorize! :index, Target
    company = current_identity.company
    slim :'company/targets', locals: {company: company, prefix: '+7-812'}
  end

  post '/company/target/upload' do
    authorize! :create, Target
    company = current_identity.company

    prefix = params[:prefix]
    prefix = prefix.nil? || prefix.empty? ? '7' : prefix
    targets = TargetExtractor.new(params[:file], prefix).extract

    loaded = []
    targets.each do |t|
      name, public_phones, ceo_phones, ceo_name = t

      next if name.nil?
      next unless company.targets.first(name: name).nil?

      target = Target.new company: company, name: name
      next unless target.save

      public_phones.each do |phone|
        puts phone
        contact = TargetContact.create target: target, phone: phone
      end

      ceo_phones.each do |phone|
        contact = TargetContact.create target: target, phone: phone, name: ceo_name, ceo: true
      end

      loaded << target
    end

    flash[:info] = "Загружено #{loaded.size} целей"

    redirect '/company/targets'
  end
end
