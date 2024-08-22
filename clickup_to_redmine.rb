#!/usr/bin/env ruby

require 'net/http'
require 'thor'
require 'json'

class RedmineMigration < Thor
  desc "import LIST_ID", "import tickets from a ClickUp list"
  def import(list_id, project_id, tracker_id)
    tasks = ClickUp.tasks(list_id)
    issues = []
    tasks.each do |task|
      issue = Issue.new(
        name: task['name'],
        description: task['text_content'],
        status: task['status']['status'],
        author: task['creator']['email'],
        estimate: task['time_estimate'], # Check this
      )
      print 'T'
      comments = ClickUp.comments(task['id'])

      comments.each do |comment|
        c = Comment.new(
          text: comment['comment_text'],
          author: comment['user']['email'],
        )

        issue.comments << c
      end
      print 'C'
      issues << issue
    end

    issues.each do |issue|
      issue_response = Redmine.create_issue(
        issue:,
        project_id:,
        tracker_id:,
      )
      puts issue.inspect
      puts issue_response.inspect
      issue.id = issue_response['issue']['id']
      issue.comments.each do |comment|
        next unless comment.class == Comment # I don’t know why I need this 😭

        puts 'goo'
        puts issue.inspect
        puts issue_response.inspect
        Redmine.add_comment(
          issue_id: issue.id,
          text: comment.text,
          author: comment.author,
        )
      end if issue.comments.any?
    end
  end
end

class Issue
  attr_accessor :name, :description, :status, :author, :comments, :estimate, :id

  def initialize(name:, description:, status:, author:, estimate:)
    @name = name
    @description = description
    @status = status
    @author = author
    @comments = [],
    @estimate = estimate
  end
end

class Comment
  attr_accessor :text, :author

  def initialize(text:, author:)
    @text = text
    @author = author
  end
end

class Redmine
  def self.create_issue(issue:, project_id:, tracker_id:)
    api_call(
      :post,
      "issues.json",
      params: {
        issue: {
          project_id: project_id,
          tracker_id: tracker_id,
          subject: issue.name,
          description: issue.description,
          estimated_hours: issue.estimate,
        }
      },
      as_user: issue.author
    )
  end

  def self.add_comment(issue_id:, text:, author: nil)
    api_call(
      :put,
      "issues/#{issue_id}.json",
      params: {
        issue: {
          notes: text,
        }
      },
      as_user: author
    )
  end

  def self.api_call(method, path, params: {}, as_user: nil)
    url = URI.parse("https://redmine.foxsoft.co.uk/#{path}")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    headers = {
      'Content-Type' => 'application/json',
      'X-Redmine-API-Key' => api_token,
    }
    headers['X-Redmine-Switch-User'] = as_user if as_user
    case method
    when :post
      request = Net::HTTP::Post.new(
        url,
        headers
      )
    when :put
      request = Net::HTTP::Put.new(
        url,
        headers
      )
    end
    request.body = params.to_json

    response = http.request(request)

    return api_call(method, path, params: params) if response.code.to_i == 412
    JSON.parse(response.read_body) unless response.is_a?(Net::HTTPNoContent)
  end

  def self.api_token
    ENV['REDMINE_API_KEY']
  end
end

class ClickUp
  def self.available_workspaces
    api_call("team")["teams"]
  end

  def self.folders(workspace_id)
    api_call("space/#{workspace_id}/folder", params: { archived: false })['folders']
  end

  def self.spaces
    api_call("team/#{team_id}/space",
                      params: {archived: false})['spaces']
  end

  def self.tasks(list_id)
    api_call("list/#{list_id}/task")['tasks']
  end

  def self.comments(task_id)
    api_call("task/#{task_id}/comment")['comments']
  end

  def self.lists(folder_id)
    api_call("folder/#{folder_id}/list")['lists']
  end

  def self.api_call(url, params: {})
    url = URI("https://api.clickup.com/api/v2/#{url}")
    url.query = URI.encode_www_form(params)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request['Authorization'] = api_token

    response = http.request(request)
    json = JSON.parse(response.read_body)
    if json.has_key?('err')
      puts "ClickUp API returned an error:"
      puts "\t#{json['ECODE']}"
      puts "\t#{json['err']}"
      exit
    end

    json
  end

  def self.api_token
    ENV['CLICKUP_API_KEY']
  end
end

RedmineMigration.start
