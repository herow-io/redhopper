class KanbanBoard

	attr_reader :columns

	def initialize project
		@project = project
		@columns_by_status = {}

		statuses = IssueStatus.sorted
		necessary_statuses = []
		WorkflowTransition.where(:tracker_id => project.trackers.map(&:id), :role_id => Role.all.map(&:id)).each do |transition|
			necessary_statuses << transition.old_status
			necessary_statuses << transition.new_status
		end
		statuses = statuses & necessary_statuses.uniq
		statuses = statuses.select { |status| !status.is_closed?  } if Feature.enabled("only_open_statuses")

		@columns = statuses.map do |status|
			@columns_by_status[status] = Column.new status
		end.compact

		project_issues = issues

		redhopper_issues = RedhopperIssue.ordered
		redhopper_issues.each do |redhopper_issue|
			issue = redhopper_issue.issue
			if project_issues.include?(issue)
				column_for_issue_status(issue.status).sorted_issues << redhopper_issue
				project_issues.delete issue
			end
		end

		project_issues.each do |issue|
			column_for_issue_status(issue.status).unsorted_issues << RedhopperIssue.new(issue: issue)
		end
	end

	private

	def column_for_issue_status status
		@columns_by_status[status]
	end

	def issues
		project_issues = Issue.visible(User.current, :project => @project)
		project_issues = project_issues.open if Feature.enabled("only_open_statuses")

		if Setting.plugin_redhopper && Setting.plugin_redhopper["hidden_tracker_ids"]
			wanted_tracker_ids = Tracker.pluck(:id).map(&:to_s) - Setting.plugin_redhopper["hidden_tracker_ids"]
			project_issues = project_issues.where(tracker: wanted_tracker_ids)
		end

		project_issues.to_a
	end

end
