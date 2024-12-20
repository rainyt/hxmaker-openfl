/*
Based on the Public Domain MaxRectanglesBinPack.cpp source by Jukka Jylänki
https://github.com/juj/RectangleBinPack/

Based on C# port by Sven Magnus 
http://unifycommunity.com/wiki/index.php?title=MaxRectanglesBinPack


Ported to ActionScript3 by DUZENGQIANG
http://www.duzengqiang.com/blog/post/971.html
This version is also public domain - do whatever you want with it.
*/

package hx.text;

import openfl.errors.Error;
import openfl.geom.Rectangle;

/**
 *  MaxRectanglesBinPack
 *  @author DUZENGQIANG
 *  @date Jun 7, 2012
 *  @version 1.0
 *  <p>SinaMicroBlog: http://weibo.com/duzengqiang</p>
 *  <p>blog: http://www.duzengqiang.com</p>
 */
class MaxRectsBinPack
{      
	private static var MAX_VALUE:Int = 0xffffff;
	
	public var binWidth:Int = 0;
	public var binHeight:Int = 0;
	public var allowRotations:Bool = false;
	
	public var usedRectangles:Array<Rectangle>;
	public var freeRectangles:Array<Rectangle>;
	
	private var score1:Int = 0; // Unused in this function. We don't need to know the score after finding the position.
	private var score2:Int = 0;
	private var bestShortSideFit:Int;
	private var bestLongSideFit:Int;
	
	public function new(width:Int, height:Int, rotations:Bool = true) 
	{
		init(width, height, rotations);
	}
	
	
	private function init(width:Int, height:Int, rotations:Bool = true):Void
	{
		usedRectangles = new Array<Rectangle>();
		freeRectangles = new Array<Rectangle>();
		
		if (count(width) % 1 != 0 ||count(height) % 1 != 0)
		{
			throw new Error("Must be 2,4,8,16,32,...512,1024,...");
		}
		binWidth = width;
		binHeight = height;
		allowRotations = rotations;
		
		var n:Rectangle = new Rectangle();
		n.x = 0;
		n.y = 0;
		n.width = width;
		n.height = height;
		
		freeRectangles.push(n);
	}
	
	private function count(n:Float):Float
	{
		if (n >= 2)
		{
			return count(n / 2);
		}
		return n;
	}
	
	/**
	 * Insert a new Rectangle 
	 * @param width
	 * @param height
	 * @param method
	 * @return 
	 * 
	 */	
	public function insert(width:Int, height:Int, method:FreeRectangleChoiceHeuristic):Rectangle 
	{
		var newNode:Rectangle  = new Rectangle();
		score1 = 0;
		score2 = 0;
		switch (method) 
		{
			case FreeRectangleChoiceHeuristic.BestShortSideFit: 
				newNode = findPositionForNewNodeBestShortSideFit(width, height); 
			case FreeRectangleChoiceHeuristic.BottomLeftRule: 
				newNode = findPositionForNewNodeBottomLeft(width, height, score1, score2); 
			case FreeRectangleChoiceHeuristic.ContactPointRule: 
				newNode = findPositionForNewNodeContactPoint(width, height, score1); 
			case FreeRectangleChoiceHeuristic.BestLongSideFit: 
				newNode = findPositionForNewNodeBestLongSideFit(width, height, score2, score1); 
			case FreeRectangleChoiceHeuristic.BestAreaFit: 
				newNode = findPositionForNewNodeBestAreaFit(width, height, score1, score2); 
		}
		
		if (newNode.height == 0)
		{
			return newNode;
		}
		
		placeRectangle(newNode);
		return newNode;
	}
	
	private function insert2(Rectangles:Array<Rectangle>, dst:Array<Rectangle>, method:FreeRectangleChoiceHeuristic):Void 
	{
		dst.splice(0, dst.length);
		
		while (Rectangles.length > 0) 
		{
			var bestScore1:Int = MaxRectsBinPack.MAX_VALUE;
			var bestScore2:Int = MaxRectsBinPack.MAX_VALUE;
			var bestRectangleIndex:Int = -1;
			var bestNode:Rectangle = new Rectangle();
			
			for (i in 0...(Rectangles.length)) 
			{
				var score1:Int = 0;
				var score2:Int = 0;
				var newNode:Rectangle = scoreRectangle(Std.int(Rectangles[i].width), Std.int(Rectangles[i].height), method, score1, score2);
				
				if (score1 < bestScore1 || (score1 == bestScore1 && score2 < bestScore2)) 
				{
					bestScore1 = score1;
					bestScore2 = score2;
					bestNode = newNode;
					bestRectangleIndex = i;
				}
			}
			
			if (bestRectangleIndex == -1)
			{
				return;
			}
			
			placeRectangle(bestNode);
			Rectangles.splice(bestRectangleIndex,1);
		}
	}
	
	private function placeRectangle(node:Rectangle):Void 
	{
		var numRectanglesToProcess:Int = freeRectangles.length;
		var i:Int = 0;
		while (i < numRectanglesToProcess)
		{
			if (splitFreeNode(freeRectangles[i], node)) 
			{
				freeRectangles.splice(i, 1);
				--i;
				--numRectanglesToProcess;
			}
			i++;
		}
		
		pruneFreeList();
		
		usedRectangles.push(node);
	}
	
	private function scoreRectangle(width:Int,  height:Int,  method:FreeRectangleChoiceHeuristic, score1:Int, score2:Int):Rectangle 
	{
		var newNode:Rectangle = new Rectangle();
		score1 = MaxRectsBinPack.MAX_VALUE;
		score2 = MaxRectsBinPack.MAX_VALUE;
		switch(method) 
		{
			case FreeRectangleChoiceHeuristic.BestShortSideFit: 
				newNode = findPositionForNewNodeBestShortSideFit(width, height); 
			case FreeRectangleChoiceHeuristic.BottomLeftRule: 
				newNode = findPositionForNewNodeBottomLeft(width, height, score1,score2); 
			case FreeRectangleChoiceHeuristic.ContactPointRule: 
				newNode = findPositionForNewNodeContactPoint(width, height, score1); 
				// todo: reverse
				score1 = -score1; // Reverse since we are minimizing, but for contact point score bigger is better.
			case FreeRectangleChoiceHeuristic.BestLongSideFit: 
				newNode = findPositionForNewNodeBestLongSideFit(width, height, score2, score1); 
			case FreeRectangleChoiceHeuristic.BestAreaFit: 
				newNode = findPositionForNewNodeBestAreaFit(width, height, score1, score2); 
		}
		
		// Cannot fit the current Rectangle.
		if (newNode.height == 0) 
		{
			score1 = MaxRectsBinPack.MAX_VALUE;
			score2 = MaxRectsBinPack.MAX_VALUE;
		}
		
		return newNode;
	}
	
	/// Computes the ratio of used surface area.
	private function occupancy():Float 
	{
		var usedSurfaceArea:Float = 0;
		for (i in 0...usedRectangles.length)
		{
			usedSurfaceArea += usedRectangles[i].width * usedRectangles[i].height;
		}
		
		return usedSurfaceArea / (binWidth * binHeight);
	}
		
	private function findPositionForNewNodeBottomLeft(width:Int, height:Int, bestY:Int, bestX:Int):Rectangle
	{
		var bestNode:Rectangle = new Rectangle();
		//memset(bestNode, 0, sizeof(Rectangle));
		
		bestY = MaxRectsBinPack.MAX_VALUE;
		var rect:Rectangle;
		var topSideY:Int;
		for (i in 0...freeRectangles.length) 
		{
			rect = freeRectangles[i];
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) 
			{
				topSideY = Std.int(rect.y) + height;
				if (topSideY < bestY || (topSideY == bestY && rect.x < bestX)) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestY = topSideY;
					bestX = Std.int(rect.x);
				}
			}
			if (allowRotations && rect.width >= height && rect.height >= width) 
			{
				topSideY = Std.int(rect.y) + width;
				if (topSideY < bestY || (topSideY == bestY && rect.x < bestX)) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestY = topSideY;
					bestX = Std.int(rect.x);
				}
			}
		}
		return bestNode;
	}
	
	private function findPositionForNewNodeBestShortSideFit(width:Int, height:Int):Rectangle 
	{
		var bestNode:Rectangle = new Rectangle();
		//memset(&bestNode, 0, sizeof(Rectangle));
		
		bestShortSideFit = MaxRectsBinPack.MAX_VALUE;
		bestLongSideFit = score2;
		var rect:Rectangle;
		var leftoverHoriz:Int;
		var leftoverVert:Int;
		var shortSideFit:Int;
		var longSideFit:Int;
		
		for (i in 0...(freeRectangles.length)) 
		{
			rect = freeRectangles[i];
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) 
			{
				leftoverHoriz = Std.int(Math.abs(rect.width - width));
				leftoverVert = Std.int(Math.abs(rect.height - height));
				shortSideFit = Std.int(Math.min(leftoverHoriz, leftoverVert));
				longSideFit = Std.int(Math.max(leftoverHoriz, leftoverVert));
				
				if (shortSideFit < bestShortSideFit || (shortSideFit == bestShortSideFit && longSideFit < bestLongSideFit)) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestShortSideFit = shortSideFit;
					bestLongSideFit = longSideFit;
				}
			}
			var flippedLeftoverHoriz:Int;
			var flippedLeftoverVert:Int;
			var flippedShortSideFit:Int;
			var flippedLongSideFit:Int;
			if (allowRotations && rect.width >= height && rect.height >= width) 
			{
				var flippedLeftoverHoriz:Int = Std.int(Math.abs(rect.width - height));
				var flippedLeftoverVert:Int = Std.int(Math.abs(rect.height - width));
				var flippedShortSideFit = Std.int(Math.min(flippedLeftoverHoriz, flippedLeftoverVert));
				var flippedLongSideFit:Int = Std.int(Math.max(flippedLeftoverHoriz, flippedLeftoverVert));
				
				if (flippedShortSideFit < bestShortSideFit || (flippedShortSideFit == bestShortSideFit && flippedLongSideFit < bestLongSideFit)) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestShortSideFit = flippedShortSideFit;
					bestLongSideFit = flippedLongSideFit;
				}
			}
		}
		
		return bestNode;
	}
	
	private function findPositionForNewNodeBestLongSideFit(width:Int, height:Int, bestShortSideFit:Int, bestLongSideFit:Int):Rectangle 
	{
		var bestNode:Rectangle = new Rectangle();
		//memset(&bestNode, 0, sizeof(Rectangle));
		bestLongSideFit = MaxRectsBinPack.MAX_VALUE;
		var rect:Rectangle;
		
		var leftoverHoriz:Int;
		var leftoverVert:Int;
		var shortSideFit:Int;
		var longSideFit:Int;
		for (i in 0...(freeRectangles.length)) 
		{
			rect = freeRectangles[i];
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) 
			{
				leftoverHoriz = Std.int(Math.abs(rect.width - width));
				leftoverVert = Std.int(Math.abs(rect.height - height));
				shortSideFit = Std.int(Math.min(leftoverHoriz, leftoverVert));
				longSideFit = Std.int(Math.max(leftoverHoriz, leftoverVert));
				
				if (longSideFit < bestLongSideFit || (longSideFit == bestLongSideFit && shortSideFit < bestShortSideFit)) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestShortSideFit = shortSideFit;
					bestLongSideFit = longSideFit;
				}
			}
			
			if (allowRotations && rect.width >= height && rect.height >= width) 
			{
				leftoverHoriz = Std.int(Math.abs(rect.width - height));
				leftoverVert = Std.int(Math.abs(rect.height - width));
				shortSideFit = Std.int(Math.min(leftoverHoriz, leftoverVert));
				longSideFit = Std.int(Math.max(leftoverHoriz, leftoverVert));
				
				if (longSideFit < bestLongSideFit || (longSideFit == bestLongSideFit && shortSideFit < bestShortSideFit)) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestShortSideFit = shortSideFit;
					bestLongSideFit = longSideFit;
				}
			}
		}
		
		return bestNode;
	}
	
	private function findPositionForNewNodeBestAreaFit(width:Int, height:Int, bestAreaFit:Int, bestShortSideFit:Int):Rectangle 
	{
		var bestNode:Rectangle = new Rectangle();
		//memset(&bestNode, 0, sizeof(Rectangle));
		
		bestAreaFit = MaxRectsBinPack.MAX_VALUE;
		
		var rect:Rectangle;
		
		var leftoverHoriz:Int;
		var leftoverVert:Int;
		var shortSideFit:Int;
		var areaFit:Int;
		
		for (i in 0...(freeRectangles.length)) 
		{
			rect = freeRectangles[i];
			areaFit = Std.int(rect.width * rect.height) - width * height;
			
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) 
			{
				leftoverHoriz = Std.int(Math.abs(rect.width - width));
				leftoverVert = Std.int(Math.abs(rect.height - height));
				shortSideFit = Std.int(Math.min(leftoverHoriz, leftoverVert));
				
				if (areaFit < bestAreaFit || (areaFit == bestAreaFit && shortSideFit < bestShortSideFit)) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestShortSideFit = shortSideFit;
					bestAreaFit = areaFit;
				}
			}
			
			if (allowRotations && rect.width >= height && rect.height >= width) 
			{
				leftoverHoriz = Std.int(Math.abs(rect.width - height));
				leftoverVert = Std.int(Math.abs(rect.height - width));
				shortSideFit = Std.int(Math.min(leftoverHoriz, leftoverVert));
				
				if (areaFit < bestAreaFit || (areaFit == bestAreaFit && shortSideFit < bestShortSideFit)) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestShortSideFit = shortSideFit;
					bestAreaFit = areaFit;
				}
			}
		}
		return bestNode;
	}
	
	/// Returns 0 if the two intervals i1 and i2 are disjoint, or the length of their overlap otherwise.
	private function commonIntervalLength(i1start:Int, i1end:Int, i2start:Int, i2end:Int):Int 
	{
		if (i1end < i2start || i2end < i1start)
		{
			return 0;
		}
		return Math.floor(Math.min(i1end, i2end) - Math.max(i1start, i2start));
	}
	
	private function contactPointScoreNode(x:Int, y:Int, width:Int, height:Int):Int 
	{
		var score:Int = 0;
		
		if (x == 0 || x + width == binWidth)
		{
			score += height;
		}
		if (y == 0 || y + height == binHeight)
		{
			score += width;
		}
		var rect:Rectangle;
		for (i in 0...(usedRectangles.length)) 
		{
			rect = usedRectangles[i];
			if (rect.x == x + width || rect.x + rect.width == x)
			{
				score += commonIntervalLength(Std.int(rect.y), Std.int(rect.y + rect.height), y, y + height);
			}
			if (rect.y == y + height || rect.y + rect.height == y)
			{
				score += commonIntervalLength(Std.int(rect.x), Std.int(rect.x + rect.width), x, x + width);
			}
		}
		return score;
	}
	
	private function findPositionForNewNodeContactPoint(width:Int, height:Int, bestContactScore:Int):Rectangle 
	{
		var bestNode:Rectangle = new Rectangle();
		//memset(&bestNode, 0, sizeof(Rectangle));
		
		bestContactScore = -1;
		
		var rect:Rectangle;
		var score:Int;
		for (i in 0...(freeRectangles.length)) 
		{
			rect = freeRectangles[i];
			// Try to place the Rectangle in upright (non-flipped) orientation.
			if (rect.width >= width && rect.height >= height) 
			{
				score = contactPointScoreNode(Std.int(rect.x), Std.int(rect.y), width, height);
				if (score > bestContactScore) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = width;
					bestNode.height = height;
					bestContactScore = score;
				}
			}
			if (allowRotations && rect.width >= height && rect.height >= width) 
			{
				score = contactPointScoreNode(Std.int(rect.x), Std.int(rect.y), height, width);
				if (score > bestContactScore) 
				{
					bestNode.x = rect.x;
					bestNode.y = rect.y;
					bestNode.width = height;
					bestNode.height = width;
					bestContactScore = score;
				}
			}
		}
		return bestNode;
	}
	
	private function splitFreeNode(freeNode:Rectangle, usedNode:Rectangle):Bool 
	{
		// Test with SAT if the Rectangles even intersect.
		if (usedNode.x >= freeNode.x + freeNode.width || usedNode.x + usedNode.width <= freeNode.x ||
			usedNode.y >= freeNode.y + freeNode.height || usedNode.y + usedNode.height <= freeNode.y)
		{
			return false;
		}
		var newNode:Rectangle;
		if (usedNode.x < freeNode.x + freeNode.width && usedNode.x + usedNode.width > freeNode.x) 
		{
			// New node at the top side of the used node.
			if (usedNode.y > freeNode.y && usedNode.y < freeNode.y + freeNode.height) 
			{
				newNode = freeNode.clone();
				newNode.height = usedNode.y - newNode.y;
				freeRectangles.push(newNode);
			}
			
			// New node at the bottom side of the used node.
			if (usedNode.y + usedNode.height < freeNode.y + freeNode.height) 
			{
				newNode = freeNode.clone();
				newNode.y = usedNode.y + usedNode.height;
				newNode.height = freeNode.y + freeNode.height - (usedNode.y + usedNode.height);
				freeRectangles.push(newNode);
			}
		}
		
		if (usedNode.y < freeNode.y + freeNode.height && usedNode.y + usedNode.height > freeNode.y) 
		{
			// New node at the left side of the used node.
			if (usedNode.x > freeNode.x && usedNode.x < freeNode.x + freeNode.width) 
			{
				newNode = freeNode.clone();
				newNode.width = usedNode.x - newNode.x;
				freeRectangles.push(newNode);
			}
			
			// New node at the right side of the used node.
			if (usedNode.x + usedNode.width < freeNode.x + freeNode.width) 
			{
				newNode = freeNode.clone();
				newNode.x = usedNode.x + usedNode.width;
				newNode.width = freeNode.x + freeNode.width - (usedNode.x + usedNode.width);
				freeRectangles.push(newNode);
			}
		}
		
		return true;
	}
	
	private function pruneFreeList():Void 
	{
		for (i in 0...(freeRectangles.length))
		{
			for (j in (i + 1)...(freeRectangles.length)) 
			{
				if (isContainedIn(freeRectangles[i], freeRectangles[j])) 
				{
					freeRectangles.splice(i, 1);
					break;
				}
				if (isContainedIn(freeRectangles[j], freeRectangles[i])) 
				{
					freeRectangles.splice(j, 1);
				}
			}
		}
	}
	
	private function isContainedIn(a:Rectangle, b:Rectangle):Bool 
	{
		if(a == null || b == null)
			return false;
		return (a.x >= b.x && a.y >= b.y 
			&& a.x+a.width <= b.x+b.width 
			&& a.y+a.height <= b.y+b.height);
	}	
}


enum FreeRectangleChoiceHeuristic {
	BestShortSideFit; ///< -BSSF: Positions the Rectangle against the short side of a free Rectangle into which it fits the best.
	BestLongSideFit; ///< -BLSF: Positions the Rectangle against the long side of a free Rectangle into which it fits the best.
	BestAreaFit; ///< -BAF: Positions the Rectangle into the smallest free Rectangle into which it fits.
	BottomLeftRule; ///< -BL: Does the Tetris placement.
	ContactPointRule; ///< -CP: Choosest the placement where the Rectangle touches other Rectangles as much as possible.
}