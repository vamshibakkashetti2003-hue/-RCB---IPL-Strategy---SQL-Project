use ipl;
####################################### OBJECTIVE QUESTIONS##############################################################################
-- 1. List the different dtypes of columns in table “ball_by_ball” (using information schema)
select column_name, data_type from information_schema.columns
where table_name = 'Ball_by_ball';
----- 2. What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)
WITH cte AS (
    SELECT 
        b.Match_Id, 
        b.Over_Id, 
        b.Ball_Id, 
        b.Innings_No, 
        b.Team_Batting, 
        t1.Team_Name AS Team_Batting_Name,
        b.Team_Bowling, 
        t2.Team_Name AS Team_Bowling_Name,
        b.Runs_Scored, 
        COALESCE(e.Extra_Runs, 0) AS Extra_Runs, 
        m.Season_Id FROM Ball_by_Ball b JOIN Team t1 ON t1.Team_Id = b.Team_Batting JOIN Team t2 ON t2.Team_Id = b.Team_Bowling
    JOIN Matches m ON m.Match_Id = b.Match_Id
    LEFT JOIN Extra_Runs e 
        ON e.Match_Id = b.Match_Id 
        AND e.Over_Id = b.Over_Id 
        AND e.Ball_Id = b.Ball_Id 
        AND e.Innings_No = b.Innings_No
)
SELECT 
    SUM(Runs_Scored + Extra_Runs) AS Total_Runs
FROM cte
WHERE Team_Batting_Name = 'Royal Challengers Bangalore' 
AND Season_Id = (SELECT MIN(Season_Id) FROM cte);

   -- Question No: 3 (How many players were more than age of 25 during season 2)
SELECT COUNT(DISTINCT p.Player_ID) AS Players_Above_25
FROM player p
JOIN player_match pm ON p.Player_ID = pm.Player_ID
JOIN matches m ON pm.Match_ID = m.Match_ID
WHERE m.Season_ID = 7 
AND TIMESTAMPDIFF(YEAR, p.Dob, m.Match_Date) > 25;
#4. How many matches did RCB win in 2013?
SELECT COUNT(*) AS RCB_Wins_2013
FROM Matches m
JOIN Season s ON m.Season_Id = s.Season_Id
JOIN Team t ON m.Match_Winner = t.Team_Id
WHERE s.Season_Year = 2013
AND t.Team_Name = 'Royal Challengers Bangalore';	
# 5.List the top 10 players according to their strike rate in the last 4 seasons
WITH Last_4_Seasons AS (
    SELECT Season_Year 
    FROM Season 
    ORDER BY Season_Year DESC 
    LIMIT 4
)SELECT 
    p.Player_Name,
    SUM(b.Runs_Scored) AS Total_Runs,
    COUNT(*) AS Balls_Faced,
    ROUND(SUM(b.Runs_Scored) * 100.0 / NULLIF(COUNT(*), 0), 2) AS Strike_Rate
FROM Ball_by_Ball b
JOIN Matches m ON b.Match_Id = m.Match_Id
JOIN Season s ON m.Season_Id = s.Season_Id
JOIN Player p ON b.Striker = p.Player_Id
JOIN Last_4_Seasons l4s ON s.Season_Year = l4s.Season_Year
LEFT JOIN Extra_Runs e ON 
    b.Match_Id = e.Match_Id AND 
    b.Over_Id = e.Over_Id AND 
    b.Ball_Id = e.Ball_Id AND 
    b.Innings_No = e.Innings_No
WHERE e.Extra_Runs IS NULL
GROUP BY b.Striker
ORDER BY Strike_Rate DESC
LIMIT 10;
# 6.What are the average runs scored by each batsman considering all the seasons?
with season_wise_runs as(SELECT s.season_year,p.player_name, sum(b.runs_scored) as total_runs
 from ball_by_ball b join matches m on b.match_id=m.match_id
 join season s on s.season_id=m.season_id
 join player p on p.player_id=b.striker
 group by s.season_year,p.player_name)
select player_name, round(avg(total_runs) ,2) as avg_runs_per_season from 
season_wise_runs group by player_name order by avg_runs_per_season desc;
#7.	What are the average wickets taken by each bowler considering all the seasons?
with season_wise_wickets as(select p.Player_Name,s.Season_Year,COUNT(wt.Player_Out) AS Wickets
from  Ball_by_Ball b join wicket_taken wt on b.match_id=wt.match_id
and b.over_id=wt.over_id and
b.ball_id=wt.ball_id
join player p on b.bowler=p.player_id
join matches m on m.match_id=b.match_id
join season s on m.season_id=s.season_id
group by p.player_name,s.season_year)
select player_name,round(avg(wickets),2) as avg_wickets
from season_wise_wickets group by player_name order by avg_wickets desc;
#8.List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average
with batting as (
  select b.striker as player_id, round(sum(b.runs_scored)*1.0/count(*),2) as avg_runs
  from ball_by_ball b group by b.striker
),
overall_batting as (select round(sum(b.runs_scored)*1.0/count(*),2) as overall_avg_runs from ball_by_ball b
),
with_bowling as (select b.bowler as player_id, count(wt.player_out) as total_wickets
  from ball_by_ball b join wicket_taken wt 
  on b.match_id=wt.match_id and b.over_id=wt.over_id and b.ball_id=wt.ball_id 
  group by b.bowler
),
overall_bowling as (select round(sum(w.total_wickets)*1.0/count(*),2) as overall_avg_wickets from (
    select b.bowler, count(wt.player_out) as total_wickets
    from ball_by_ball b join wicket_taken wt 
    on b.match_id=wt.match_id and b.over_id=wt.over_id and b.ball_id=wt.ball_id 
    group by b.bowler
  ) w
)select p.player_name, bat.avg_runs, coalesce(bowl.total_wickets,0) as total_wickets
from batting bat 
join player p on bat.player_id=p.player_id
left join with_bowling bowl on bat.player_id=bowl.player_id
join overall_batting ob on bat.avg_runs > ob.overall_avg_runs
join overall_bowling ow on coalesce(bowl.total_wickets,0) > ow.overall_avg_wickets;
#9.Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.
CREATE TABLE rcb_record AS
SELECT 
    v.Venue_Name,
    SUM(CASE 
            WHEN m.Match_Winner = t.Team_Id THEN 1 
            ELSE 0 
        END) AS Wins,
    SUM(CASE 
            WHEN m.Match_Winner != t.Team_Id AND (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id) THEN 1 
            ELSE 0 
        END) AS Losses
FROM Matches m
INNER JOIN Team t ON t.Team_Name = 'Royal Challengers Bangalore'
INNER JOIN Venue v ON m.Venue_Id = v.Venue_Id
WHERE m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id
GROUP BY v.Venue_Name;
SELECT * FROM rcb_record;
#10.What is the impact of bowling style on wickets taken?
Select bs.bowling_skill as bowling_style, count(*) as total_wickets
from wicket_taken wt
join player p on wt.player_out= p.player_id
join bowling_style bs on p.bowling_skill=bs.bowling_id
group by bs.bowling_skill
order by total_wickets desc;
#11..Write the SQL query to provide a status of whether the performance of the team is better than the previous year's
#performance on the basis of the number of runs scored by the team in the season and the number of wickets taken 
with teamperformance as (Select t.team_name,s.season_year,sum(b.runs_scored) as total_runs,count(wt.player_out) as total_wickets from team t
inner join player_match pm on t.team_id = pm.team_id
inner join matches m on pm.match_id = m.match_id
inner join season s on m.season_id = s.season_id
left join ball_by_ball b on pm.match_id=b.match_id and pm.player_id = b.striker
left join wicket_taken wt on pm.match_id =wt.match_id and pm.player_id= wt.player_out
group by t.team_name, s.season_year)select t1.team_name,t1.season_year as previous_year,
t2.season_year as current_year,t1.total_runs as previous_runs,
t2.total_runs as current_runs,t1.total_wickets as previous_wickets,
t2.total_wickets current_wickets, case when t2.total_runs > t1.total_runs 
and t2.total_wickets> t1.total_wickets then 'Better'
when t2.total_runs = t1.total_runs 
and t2.total_wickets = t1.total_wickets then 'Same'
when (t2.total_runs > t1.total_runs 
and t2.total_wickets<= t1.total_wickets) or
(t2.total_runs <= t1.total_runs 
and t2.total_wickets> t1.total_wickets) then 'Mixed'
else 'Worse' end as Performance_Status from teamPerformance t1
inner join teamperformance t2
on t1.team_name = t2.team_name
and t1.season_year = t2.season_year -1
order by t1.team_name, t1.season_year;
#12.Can you derive more KPIs for the team strategy?
#A. Bowling Strike Rate
SELECT bb.Bowler,p.Player_Name, 
ROUND(COUNT(bb.Ball_Id) / COUNT(w.Player_Out),2) AS Strike_Rate
FROM ball_by_ball bb
LEFT JOIN wicket_taken w 
ON bb.Match_Id = w.Match_Id 
AND bb.Over_Id = w.Over_Id 
AND bb.Ball_Id = w.Ball_Id
JOIN Player p
ON p.Player_Id = bb.Bowler
WHERE bb.Team_Bowling = 2
GROUP BY bb.Bowler
HAVING Strike_Rate IS NOT NULL
ORDER BY Strike_Rate ASC
LIMIT 15;

#2. Boundaries hit percentage
SELECT p.Player_Name,ROUND((SUM(CASE WHEN b.Runs_Scored IN (4, 6) THEN 1 ELSE 0 END) * 100.0) / COUNT(*),2) AS Boundaries_hits
FROM Ball_by_Ball b JOIN Player p ON b.Striker = p.Player_Id GROUP BY p.Player_Name ORDER BY Boundaries_hits DESC
LIMIT 10;
#3. Powerplay Performance
SELECT t.Team_Name, b.Team_Batting, SUM(b.Runs_Scored) AS Powerplay_Runs, COUNT(w.Player_Out) AS Powerplay_Wickets FROM Ball_by_Ball b
LEFT JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id AND b.Over_Id = w.Over_Id AND b.Ball_Id = w.Ball_Id JOIN Team t ON b.Team_Batting = t.Team_Id
WHERE b.Over_Id BETWEEN 1 AND 6 GROUP BY b.Team_Batting, t.Team_Name ORDER BY Powerplay_Runs DESC;
#4. Death Over Performance
SELECT p.player_name , t.Team_Name, b.Team_Batting, SUM(b.Runs_Scored) AS Death_Over_Runs, COUNT(w.Player_Out) AS Death_Over_Wickets
FROM Ball_by_Ball b LEFT JOIN Wicket_Taken w ON b.Match_Id = w.Match_Id AND b.Over_Id = w.Over_Id AND b.Ball_Id = w.Ball_Id
JOIN Team t ON b.Team_Batting = t.Team_Id JOIN Player p 
    ON b.striker = p.player_id WHERE b.Over_Id BETWEEN 17 AND 20 GROUP BY b.Team_Batting, t.Team_Name,p.player_name
ORDER BY Death_Over_Runs DESC limit 10;
#5.Win_Loss Ratio
SELECT t.Team_Name,v.Venue_Name,
SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Wins,SUM(CASE WHEN m.Match_Winner != t.Team_Id 
AND (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id) 
THEN 1 ELSE 0 END) AS Losses,
ROUND(CASE WHEN SUM(CASE 
WHEN m.Match_Winner != t.Team_Id 
AND (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id) 
THEN 1 ELSE 0 END) = 0 THEN SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END)
ELSE SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) * 1.0 
/ SUM(CASE WHEN m.Match_Winner != t.Team_Id AND (m.Team_1 = t.Team_Id OR m.Team_2 = t.Team_Id) THEN 1 ELSE 0 END)END, 2) AS Win_Loss_Ratio
FROM Matches m
JOIN Team t ON t.Team_Id IN (m.Team_1, m.Team_2)
JOIN Venue v ON v.Venue_Id = m.Venue_Id
GROUP BY t.Team_Name, v.Venue_Name
ORDER BY Wins DESC, Losses ASC
LIMIT 20;
#13. Average wicket By each bowlwer on each venue
WITH Bowler_Wickets_Per_Venue AS (
    SELECT  b.Bowler, p.Player_Name, v.Venue_Name, COUNT(*) AS Total_Wickets FROM Wicket_Taken w JOIN Ball_by_Ball b 
        ON w.Match_Id = b.Match_Id 
        AND w.Over_Id = b.Over_Id 
        AND w.Ball_Id = b.Ball_Id 
        AND w.Innings_No = b.Innings_No
    JOIN Matches m ON w.Match_Id = m.Match_Id
    JOIN Venue v ON m.Venue_Id = v.Venue_Id
    JOIN Player p ON b.Bowler = p.Player_Id
    GROUP BY b.Bowler, p.Player_Name, v.Venue_Name
)SELECT Player_Name, venue_Name, ROUND(AVG(Total_Wickets * 1.0), 2) AS Avg_Wickets
FROM Bowler_Wickets_Per_Venue
GROUP BY Player_Name, Venue_Name
ORDER BY Avg_Wickets DESC;
#14. Which of the given players have consistently performed well in past seasons? 
WITH Player_Season_Performance AS (
    SELECT 
        p.Player_Name, 
        s.Season_Year,
        SUM(CASE WHEN b.Striker = p.Player_Id THEN b.Runs_Scored ELSE 0 END) AS Total_Runs,
        COUNT(DISTINCT CASE WHEN wt.Player_Out = p.Player_Id THEN b.Match_Id END) AS Total_Wickets
    FROM Player p 
    LEFT JOIN Ball_by_Ball b 
        ON p.Player_Id = b.Striker OR p.Player_Id = b.Bowler
    LEFT JOIN Matches m 
        ON b.Match_Id = m.Match_Id
    LEFT JOIN Season s 
        ON m.Season_Id = s.Season_Id
    LEFT JOIN Wicket_Taken wt 
        ON b.Match_Id = wt.Match_Id 
        AND b.Over_Id = wt.Over_Id 
        AND b.Ball_Id = wt.Ball_Id 
        AND b.Innings_No = wt.Innings_No 
    GROUP BY p.Player_Name, s.Season_Year
)SELECT Player_Name, COUNT(DISTINCT Season_Year) AS Seasons_Played,AVG(Total_Runs) AS Avg_Runs_Per_Season, AVG(Total_Wickets) AS Avg_Wickets_Per_Season
FROM Player_Season_Performance 
GROUP BY Player_Name HAVING COUNT(DISTINCT Season_Year) > 2
Order by Avg_Runs_per_Season desc, Avg_Wickets_per_season desc limit 10;
#15.Are there players whose performance is more suited to specific venues or conditions? 
WITH Player_Performance AS (
  SELECT 
    p.Player_Name,
    v.Venue_Name,
    AVG(bbb.Runs_Scored) AS Avg_Runs,
    COUNT(wt.Player_Out) AS Wickets_Taken
  FROM player p
  INNER JOIN ball_by_ball bbb ON p.Player_Id = bbb.Striker
  INNER JOIN matches m ON m.Match_Id = bbb.Match_Id
  INNER JOIN venue v ON m.Venue_Id = v.Venue_Id
  LEFT JOIN wicket_taken wt 
    ON bbb.Match_Id = wt.Match_Id 
    AND bbb.Over_Id = wt.Over_Id 
    AND bbb.Ball_Id = wt.Ball_Id 
    AND p.Player_Id = wt.Player_Out
  GROUP BY p.Player_Name, v.Venue_Name
  HAVING AVG(bbb.Runs_Scored) > 30 OR COUNT(wt.Player_Out) > 5
)SELECT 
  Player_Name,
  Venue_Name,
  MAX(Avg_Runs) AS Max_Avg_Runs,
  MAX(Wickets_Taken) AS Max_Wickets_Taken
FROM Player_Performance
GROUP BY Player_Name, Venue_Name
ORDER BY Max_Avg_Runs DESC, Max_Wickets_Taken DESC;
#SUBJECTIVE QUESTIONS 
#1.How does the toss decision affect the result of the match? And is the impact limited to only specific venues?
WITH toss_data as (
select match_id,toss_winner, toss_decide, match_winner, venue_id, toss_name from matches join
toss_decision on matches.toss_decide=toss_decision.toss_id
where match_winner is not null),
venue_info as(
select venue_id, venue_name from venue),
joined_data as(
select td.*,vi.venue_name, case when td.toss_winner=td.match_winner then 1 else 0 
end as toss_win_match_win from toss_data td join venue_info vi on td.venue_id = vi.venue_id)
Select venue_name ,toss_name, toss_decide, count(*) as total_matches , sum(toss_win_match_win) as 
match_won_after_toss, round(sum(toss_win_match_win) * 100.0/ count(*), 2) as win_percentage
from joined_data  group by venue_name , toss_decide having count(*) > 10  order by venue_name , toss_decide;
#2 - Suggest some of the players who would be best fit for the team)
#List of consistently performing batsmen 
SELECT p.Player_Name, 
       SUM(bs.Runs_Scored) AS Total_Runs, 
       COUNT(bb.Ball_Id) AS Balls_Faced, 
       ROUND((SUM(bs.Runs_Scored) / COUNT(bb.Ball_Id))*100,2) AS Strike_Rate, 
       ROUND(SUM(bs.Runs_Scored) / COUNT(DISTINCT m.Match_Id), 2) AS Average_Runs
FROM player p
JOIN ball_by_ball bb ON p.Player_Id = bb.Striker
JOIN ball_by_ball bs ON bb.Match_Id = bs.Match_Id AND bb.Innings_No = bs.Innings_No AND bb.Over_Id = bs.Over_Id AND bb.Ball_Id = bs.Ball_Id
JOIN matches m ON bb.Match_Id = m.Match_Id
WHERE m.Season_Id >= 4
GROUP BY p.Player_Name
ORDER BY Total_Runs DESC,Strike_Rate DESC
LIMIT 10;

#List of consistent bowlers
SELECT p.Player_Name, 
       COUNT(w.Player_Out) AS Wickets_Taken, 
       ROUND(SUM(bb.Ball_Id) / COUNT(w.Player_Out),2) AS Strike_Rate, 
       ROUND(SUM(bb.Runs_Scored) / (SUM(bb.Ball_Id)/6),2) AS Economy_Rate
FROM ball_by_ball bb
JOIN Player p 
ON bb.bowler = p.Player_Id
JOIN matches m ON bb.Match_Id = m.Match_Id
JOIN wicket_taken w 
ON bb.Match_Id = w.Match_Id AND bb.Over_Id = w.Over_Id AND bb.Innings_No = w.Innings_No AND bb.Ball_Id = w.Ball_Id
WHERE m.Season_Id >=4
GROUP BY p.Player_Name
ORDER BY Wickets_Taken DESC, Economy_Rate ASC, Strike_Rate ASC
LIMIT 10;


#3.	What are some of the parameters that should be focused on while selecting the players?
#A. Death over bowling performance
SELECT p.Player_Name, 
      SUM(CASE 
          WHEN bb.Over_Id >= 16 AND bb.Over_Id <= 20  
          AND p.Player_Id IN (SELECT Bowler FROM ball_by_ball) THEN bb.Runs_Scored ELSE 0 END) AS Death_Over_Runs_Conceded
	FROM player p
JOIN ball_by_ball bb ON p.Player_Id = bb.Striker OR p.Player_Id = bb.Bowler
GROUP BY p.Player_Name
HAVING COUNT(bb.Ball_Id) > 100 AND Death_Over_Runs_Conceded != 0
ORDER BY Death_Over_Runs_Conceded ASC
LIMIT 10;

# B. Batting performance across different venues

SELECT p.Player_Name,v.Venue_Id, v.Venue_Name, SUM(bb.Runs_Scored) AS Total_Runs, COUNT(bb.Ball_Id) AS Balls_Faced, 
ROUND(SUM(bb.Runs_Scored) / COUNT(bb.Ball_Id), 2)*100 AS Strike_Rate
FROM player p
JOIN ball_by_ball bb ON p.Player_Id = bb.Striker
JOIN matches m ON bb.Match_Id = m.Match_Id
JOIN venue v ON m.Venue_Id = v.Venue_Id
GROUP BY p.Player_Name,v.Venue_Id, v.Venue_Name
ORDER BY Total_Runs DESC, Strike_Rate DESC
LIMIT 10;


#4.Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)
with player_stats as (
select p.player_name,
sum(case when b.striker = p.player_id then b.runs_scored else 0 end) as total_runs,
count(case when b.striker = p.player_id then 1 end) as balls_faced,
sum(case when wt.player_out = p.player_id then 1 else 0 end) as total_wickets,
sum(case when b.bowler = p.player_id then b.runs_scored else 0 end) as runs_conceded,
count(case when b.bowler = p.player_id then 1 end) as balls_bowled
from player p
left join ball_by_ball b on p.player_id = b.striker or p.player_id = b.bowler
left join wicket_taken wt on b.match_id = wt.match_id and b.over_id = wt.over_id and b.ball_id = wt.ball_id and b.innings_no = wt.innings_no
group by p.player_name)
select player_name, total_runs, total_wickets, round((total_runs * 100.0) / nullif(balls_faced, 0), 2) as strike_rate,
 round((runs_conceded * 6.0) / nullif(balls_bowled, 0), 2) as economy_rate from player_stats where total_runs > 500 and total_wickets > 20 
 order by total_runs desc, total_wickets desc
 limit 10;
#5.Are there players whose presence positively influences the morale and performance of the team? 

with mom_data as (
select 
p.player_name,
count(m.match_id) as mom_awards from matches m
join player p on m.man_of_the_match = p.player_id
group by p.player_name
),
matches_played as (
select 
p.player_name,
count(distinct pm.match_id) as total_matches,
t.team_name from player p
join player_match pm on p.player_id = pm.player_id
join team t on pm.team_id = t.team_id
group by p.player_name, p.player_id, t.team_name
)
select md.player_name, mp.team_name,md.mom_awards, mp.total_matches, 
round((md.mom_awards * 100.0) / mp.total_matches, 2) as impact_percentage
from mom_data md
join matches_played mp on md.player_name = mp.player_name
where mp.total_matches > 5
order by impact_percentage desc limit 10;
#8.Analyze the impact of home-ground advantage on team performance 
WITH home_matches AS (
    SELECT m.match_id, CASE 
WHEN m.team_1 = t.team_id THEN m.team_1
WHEN m.team_2 = t.team_id THEN m.team_2
END AS team_id, team_name, m.match_winner,v.venue_id
FROM matches m 
JOIN team t ON (m.team_1 = t.team_id OR m.team_2 = t.team_id) 
JOIN venue v ON m.venue_id = v.venue_id
WHERE (m.team_1 = t.team_id OR m.team_2 = t.team_id) AND m.venue_id = v.venue_id 
)
SELECT team_id, 
       team_name, 
       COUNT(*) AS total_home_matches, 
       SUM(CASE WHEN match_winner = team_id THEN 1 ELSE 0 END) AS home_matches_won,
       ROUND(SUM(CASE WHEN match_winner = team_id THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS home_win_percentage
FROM home_matches
GROUP BY team_id, team_name
ORDER BY team_id;
#9.
-- Question No: 9 (RCB past seasons performance)
WITH RCB_Performance AS (
    SELECT
        m.Season_Id AS Season_Id,
        COUNT(m.Match_Id) AS Matches_Played,
        SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) AS Matches_Won,
        SUM(CASE WHEN m.Match_Winner != t.Team_Id THEN 1 ELSE 0 END) AS Matches_Lost,
        (SUM(CASE WHEN m.Match_Winner = t.Team_Id THEN 1 ELSE 0 END) / COUNT(m.Match_Id)) * 100 AS Win_Percentage
    FROM matches m
    INNER JOIN team t ON t.Team_Id = m.Team_1 OR t.Team_Id = m.Team_2
    WHERE t.Team_Name = 'Royal Challengers Bangalore'
    GROUP BY m.Season_Id
)
SELECT
    s.Season_Year,
    rp.Matches_Played,
    rp.Matches_Won,
    rp.Matches_Lost,
    rp.Win_Percentage
FROM RCB_Performance rp
INNER JOIN Season s ON rp.Season_Id = s.Season_Id
ORDER BY s.Season_Year;
#11.In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".
UPDATE Matches
SET Opponent_Team = 'Delhi_Daredevils'
WHERE Opponent_Team = 'Delhi_Capitals';
Select team_name from team;










