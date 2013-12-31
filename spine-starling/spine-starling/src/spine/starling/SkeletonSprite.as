/******************************************************************************
 * Spine Runtime Software License - Version 1.1
 * 
 * Copyright (c) 2013, Esoteric Software
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms in whole or in part, with
 * or without modification, are permitted provided that the following conditions
 * are met:
 * 
 * 1. A Spine Essential, Professional, Enterprise, or Education License must
 *    be purchased from Esoteric Software and the license must remain valid:
 *    http://esotericsoftware.com/
 * 2. Redistributions of source code must retain this license, which is the
 *    above copyright notice, this declaration of conditions and the following
 *    disclaimer.
 * 3. Redistributions in binary form must reproduce this license, which is the
 *    above copyright notice, this declaration of conditions and the following
 *    disclaimer, in the documentation and/or other materials provided with the
 *    distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

package spine.starling {
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;

import spine.Bone;
import spine.Skeleton;
import spine.SkeletonData;
import spine.Slot;
import spine.atlas.AtlasPage;
import spine.atlas.AtlasRegion;
import spine.attachments.RegionAttachment;

import starling.animation.IAnimatable;
import starling.core.RenderSupport;
import starling.display.BlendMode;
import starling.display.DisplayObject;
import starling.display.QuadBatch;
import starling.utils.Color;
import starling.utils.MatrixUtil;
import starling.utils.VertexData;

public class SkeletonSprite extends DisplayObject implements IAnimatable {
	static private var tempPoint:Point = new Point();
	static private var tempMatrix:Matrix = new Matrix();
	static private var tempVertices:Vector.<Number> = new Vector.<Number>(8);
	
	private var _skeleton:Skeleton;
	
	private var _needsUpdatedQuadBatches:Boolean = false;
	
	private var _quadBatches:Vector.<QuadBatch>;
	private var _currentQuadBatchID:int;
	
	public function SkeletonSprite (skeletonData:SkeletonData) {
		Bone.yDown = true;

		_currentQuadBatchID = 0;
		// always at least one base QuadBatch instance in array
		_quadBatches = new <QuadBatch>[new QuadBatch()];
		
		// we default to allowing the first quadbatch in this sprite to be batched (if possible)
		batchable = true;
		
		_skeleton = new Skeleton(skeletonData);
		_skeleton.updateWorldTransform();
		
		updateQuadBatches();
	}

	/** Disposes all quad batches. */
	override public function dispose():void
	{
		for each (var quadBatch:QuadBatch in _quadBatches)
			quadBatch.dispose();
			
		super.dispose();
	}
	
	/** Dictates whether this skeleton's qudbatches (the first one if multiple) will attempt
	 * to batch with the current render state 
	 */
	public function get batchable():Boolean { return _quadBatches[0].batchable; }
	public function set batchable(value:Boolean):void { 
		_quadBatches[0].batchable = value;
	} 
	
	/** Disposes redundant quad batches if the number of allocated batches is more than
	 *  twice the number of used batches. Only executed when there are at least 8 batches. */
	private function trimQuadBatches():void
	{
		var numUsedBatches:int  = _currentQuadBatchID + 1;
		var numTotalBatches:int = _quadBatches.length;
		
		if (numTotalBatches >= 8 && numTotalBatches > 2*numUsedBatches)
		{
			var numToRemove:int = numTotalBatches - numUsedBatches;
			for (var i:int=0; i<numToRemove; ++i)
				_quadBatches.pop().dispose();
		}
	}
	
	/** Normally you would not call this directly but allow the needs update flag to
	 * be set by advanceTime or other property changes that will then update the rendering QuadBatches 
	 * at the beginning of the next render pass.  
	 * 
	 * This is public in case you want to force an immediate update of QuadBatches for some reason
	 */
	public function updateQuadBatches():void {
		_needsUpdatedQuadBatches = false;
		
		trimQuadBatches();
		
		_currentQuadBatchID = 0;
		_quadBatches[_currentQuadBatchID].reset();
		
		var blendMode:String;
		var alpha:Number = this.alpha * skeleton.a;
		var r:Number = skeleton.r * 255;
		var g:Number = skeleton.g * 255;
		var b:Number = skeleton.b * 255;
		var x:Number = skeleton.x;
		var y:Number = skeleton.y;
		var drawOrder:Vector.<Slot> = skeleton.drawOrder;
		var slot:Slot;
		var a:Number;
		var image:SkeletonImage;
		var rgb:uint;
		var vertexData:VertexData;
		var regionAttachment:RegionAttachment;
		for (var i:int = 0, n:int = drawOrder.length; i < n; i++) {
			slot = drawOrder[i];
			regionAttachment = slot.attachment as RegionAttachment;
			if (regionAttachment != null) {
				regionAttachment.computeWorldVertices(x, y, slot.bone, tempVertices);
				a = slot.a;
				rgb = ((r * slot.r) << 16) | ((g * slot.g) << 8) | (b * slot.b);
				image = regionAttachment.rendererObject as SkeletonImage;
				if (image == null) {
					image = SkeletonImage(AtlasRegion(regionAttachment.rendererObject).rendererObject);
					regionAttachment.rendererObject = image;
				}
				
				vertexData = image.vertexData;
				
				vertexData.setPosition(0, tempVertices[2], tempVertices[3]);
				vertexData.setColorAndAlpha(0, rgb, a);
				
				vertexData.setPosition(1, tempVertices[4], tempVertices[5]);
				vertexData.setColorAndAlpha(1, rgb, a);
				
				vertexData.setPosition(2, tempVertices[0], tempVertices[1]);
				vertexData.setColorAndAlpha(2, rgb, a);
				
				vertexData.setPosition(3, tempVertices[6], tempVertices[7]);
				vertexData.setColorAndAlpha(3, rgb, a);
				
				image.updateVertices();
				
				blendMode = slot.data.additiveBlending ? BlendMode.ADD : BlendMode.NORMAL;
				
				if (_quadBatches[_currentQuadBatchID].isStateChange(image.tinted, alpha, image.texture, 
					image.smoothing, blendMode))
				{
					++_currentQuadBatchID;
					if (_quadBatches.length <= _currentQuadBatchID)
						_quadBatches[_currentQuadBatchID] = new QuadBatch();
					else 
						_quadBatches[_currentQuadBatchID].reset();
						
				}
				
				_quadBatches[_currentQuadBatchID].addQuad(image, alpha, image.texture, image.smoothing, 
					null, blendMode);

			}
		}
	}
	
	public function advanceTime (delta:Number) : void {
		_skeleton.update(delta);
		
		_needsUpdatedQuadBatches = true;
	}

	override public function render (support:RenderSupport, alpha:Number) : void {
		
		if (_needsUpdatedQuadBatches) {
			updateQuadBatches();
		}
		
		// we just render our existing updated QuadBatches
		var numUsedBatches:int  = _currentQuadBatchID + 1;
		var thisQuadBatch:QuadBatch;
		for (var i:int=0; i<numUsedBatches; ++i) {
			thisQuadBatch = _quadBatches[i];
			// support.blendMode is a necessary call currently because of the way RenderSupport
			// currently seems to actually ignore the QuadBatch's blendMode if different than current
			// RenderSupport value
			support.blendMode = thisQuadBatch.blendMode;
			thisQuadBatch.render(support, alpha);
		}
	}

	override public function hitTest (localPoint:Point, forTouch:Boolean = false) : DisplayObject {
		if (forTouch && (!visible || !touchable))
			return null;

		var minX:Number = Number.MAX_VALUE, minY:Number = Number.MAX_VALUE;
		var maxX:Number = Number.MIN_VALUE, maxY:Number = Number.MIN_VALUE;
		var slots:Vector.<Slot> = skeleton.slots;
		var value:Number;
		var slot:Slot;
		var regionAttachment:RegionAttachment;
		for (var i:int = 0, n:int = slots.length; i < n; i++) {
			slot = slots[i];
			regionAttachment = slot.attachment as RegionAttachment;
			if (!regionAttachment)
				continue;

			regionAttachment.computeWorldVertices(skeleton.x, skeleton.y, slot.bone, tempVertices);

			value = tempVertices[0];
			if (value < minX)
				minX = value;
			if (value > maxX)
				maxX = value;

			value = tempVertices[1];
			if (value < minY)
				minY = value;
			if (value > maxY)
				maxY = value;

			value = tempVertices[2];
			if (value < minX)
				minX = value;
			if (value > maxX)
				maxX = value;

			value = tempVertices[3];
			if (value < minY)
				minY = value;
			if (value > maxY)
				maxY = value;

			value = tempVertices[4];
			if (value < minX)
				minX = value;
			if (value > maxX)
				maxX = value;

			value = tempVertices[5];
			if (value < minY)
				minY = value;
			if (value > maxY)
				maxY = value;

			value = tempVertices[6];
			if (value < minX)
				minX = value;
			if (value > maxX)
				maxX = value;

			value = tempVertices[7];
			if (value < minY)
				minY = value;
			if (value > maxY)
				maxY = value;
		}

		minX *= scaleX;
		maxX *= scaleX;
		minY *= scaleY;
		maxY *= scaleY;
		var temp:Number;
		if (maxX < minX) {
			temp = maxX;
			maxX = minX;
			minX = temp;
		}
		if (maxY < minY) {
			temp = maxY;
			maxY = minY;
			minY = temp;
		}

		if (localPoint.x >= minX && localPoint.x < maxX && localPoint.y >= minY && localPoint.y < maxY)
			return this;

		return null;
	}

	override public function getBounds (targetSpace:DisplayObject, resultRect:Rectangle = null) : Rectangle {
		if (!resultRect)
			resultRect = new Rectangle();
		if (targetSpace == this)
			resultRect.setTo(0, 0, 0, 0);
		else if (targetSpace == parent)
			resultRect.setTo(x, y, 0, 0);
		else {
			getTransformationMatrix(targetSpace, tempMatrix);
			MatrixUtil.transformCoords(tempMatrix, 0, 0, tempPoint);
			resultRect.setTo(tempPoint.x, tempPoint.y, 0, 0);
		}
		return resultRect;
	}

	public function get skeleton () : Skeleton {
		return _skeleton;
	}
}

}
