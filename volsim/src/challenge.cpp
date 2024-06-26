#include "challenge.hpp"
#include <glm/gtc/matrix_transform.hpp>
#include <glm/glm.hpp>
#include <unordered_map>
#include "filesystem.hpp"
#include <iostream>

Challenge::Challenge(std::shared_ptr<Renderer> renderer, std::shared_ptr<Hand> hand, int challengeNum, glm::vec3 centre)
{
	this->centre = centre;
	this->renderer = renderer;
	this->hand = hand;
	std::string challengePath;
	if (challengeNum < 0) {
		challengePath = "data/challenges/demo" + std::to_string(-challengeNum) + ".txt";
	} else {
		challengePath = "data/challenges/task" + std::to_string(challengeNum) + ".txt";
	}
	std::vector<glm::vec3> directions = loadDirections(FileSystem::getPath(challengePath));

	glm::vec3 point = centre + glm::vec3(-3.0, -8.0, 2.0);
	glm::vec3 oldPoint;

	for (auto direction : directions)
	{
		oldPoint = point;
		point = oldPoint + direction;
		segments.push_back(Segment(oldPoint, point, 0.15));
	}

	startTime = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch());
}

std::vector<glm::vec3> Challenge::loadDirections(const std::string &path)
{
	std::vector<glm::vec3> directions;
	std::ifstream file(path);
	std::string line;

	// Mapping of direction keywords to base glm::vec3 vectors
	std::unordered_map<std::string, glm::vec3> directionMap = {
		{"up", glm::vec3(0.0, 1.0, 0.0)},
		{"down", glm::vec3(0.0, -1.0, 0.0)},
		{"forward", glm::vec3(0.0, 0.0, 1.0)},
		{"back", glm::vec3(0.0, 0.0, -1.0)},
		{"right", glm::vec3(1.0, 0.0, 0.0)},
		{"left", glm::vec3(-1.0, 0.0, 0.0)}};

	while (getline(file, line))
	{
		std::istringstream iss(line);
		std::string keyword;
		float length;

		if (iss >> keyword >> length)
		{
			auto it = directionMap.find(keyword);
			if (it != directionMap.end())
			{
				directions.push_back(it->second * length);
			}
			else
			{
				std::cerr << "Warning: Unknown direction keyword '" << keyword << "' in file." << std::endl;
			}
		}
		else
		{
			std::cerr << "Warning: Invalid line format in file: '" << line << "'." << std::endl;
		}
	}

	return directions;
}

void Challenge::update()
{
	if (segments.size() == completedCnt)
	{
		finished = true;
		return;
	}
	if (hand->getGrabPosition().has_value())
	{
		grabbing = true;
		grabPos = hand->getGrabPosition().value();

		Segment lastSegment = Segment(glm::vec3(0), glm::vec3(0), 0);
		lastSegment.completed = true;
		for (int i = completedCnt; i < segments.size(); i++)
		{
			Segment &segment = segments[i];
			if (segment.completed)
			{
				lastSegment = segment;
				completedCnt++;
				continue;
			}
			if (!lastSegment.completed)
			{
				break;
			}

			if (!segment.completed && (glm::distance(segment.end, grabPos) < (segment.radius * 3)))
			{
				segment.completed = true;
				segment.completedTime = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch());
				// std::cout << "Segment completed in " << (segment.completedTime - startTime).count() << "ms" << std::endl;
			}
			lastSegment = segment;
		}
	}
	else
	{
		grabbing = false;
	}
}

void Challenge::draw()
{
	float width = 10;
	float length = 20;
	renderer->drawCuboid(centre, width, length, 0.1, 0);

	renderer->drawLine(centre + glm::vec3(-width / 2.0f, -length / 2.0f, 0), centre + glm::vec3(-width / 2.0f, -length / 2.0f, width), 0.05, 0);
	renderer->drawLine(centre + glm::vec3(width / 2.0f, -length / 2.0f, 0), centre + glm::vec3(width / 2.0f, -length / 2.0f, width), 0.05, 0);
	renderer->drawLine(centre + glm::vec3(-width / 2.0f, length / 2.0f, 0), centre + glm::vec3(-width / 2.0f, length / 2.0f, width), 0.05, 0);
	renderer->drawLine(centre + glm::vec3(width / 2.0f, length / 2.0f, 0), centre + glm::vec3(width / 2.0f, length / 2.0f, width), 0.05, 0);

	renderer->drawLine(centre + glm::vec3(-width / 2.0f, -length / 2.0f, width), centre + glm::vec3(width / 2.0f, -length / 2.0f, width), 0.05, 0);
	renderer->drawLine(centre + glm::vec3(-width / 2.0f, length / 2.0f, width), centre + glm::vec3(width / 2.0f, length / 2.0f, width), 0.05, 0);
	renderer->drawLine(centre + glm::vec3(-width / 2.0f, -length / 2.0f, width), centre + glm::vec3(-width / 2.0f, length / 2.0f, width), 0.05, 0);
	renderer->drawLine(centre + glm::vec3(width / 2.0f, -length / 2.0f, width), centre + glm::vec3(width / 2.0f, length / 2.0f, width), 0.05, 0);

	renderer->drawPoint(segments.front().start, segments.front().radius * 3, 2);
	Segment lastSegment = Segment(glm::vec3(0), glm::vec3(0), 0);
	lastSegment.completed = true;
	for (Segment &segment : segments)
	{
		if (segment.completed)
		{
			renderer->drawLine(segment.start, segment.end, segment.radius, 2);
			renderer->drawPoint(segment.end, segment.radius * 3, 2);
		}
		else
		{
			if (lastSegment.completed)
			{
				if (grabbing)
				{
					renderer->drawLine(segment.start, grabPos, segment.radius, 2);
				}
				renderer->drawPoint(segment.end, segment.radius * 3, 4);
				renderer->drawLine(segment.start, segment.end, segment.radius / 2.0f, 4);
			}
			else
			{
				renderer->drawPoint(segment.end, segment.radius * 3, 0);
				renderer->drawLine(segment.start, segment.end, segment.radius / 2.0f, 0);
			}
			
		}
		lastSegment = segment;
	}
}

nlohmann::json Challenge::returnJson()
{
	nlohmann::json jsonOutput;
	for (int i = 0; i < segments.size(); i++)
	{
		Segment &segment = segments[i];
		jsonOutput.push_back({{"index", i},
							  {"completedTime", segment.completedTime.count()}});
	}
	return jsonOutput;
}

Challenge::Segment::Segment(glm::vec3 start, glm::vec3 end, float radius)
{
	this->start = start;
	this->end = end;
	this->radius = radius;
	this->completed = false;
	this->completedTime = std::chrono::milliseconds(0);
}

bool Challenge::isFinished()
{
	return finished;
}