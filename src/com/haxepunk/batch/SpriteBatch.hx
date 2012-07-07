package com.haxepunk.batch;

#if (cpp || neko)

import nme.display.BitmapData;
import nme.display.Graphics;
import nme.display.Tilesheet;
import nme.geom.Rectangle;
import nme.geom.Point;
import nme.Assets;
import haxe.EnumFlags;

import com.haxepunk.HXP;

enum RenderFlags
{
	Scale;
	Rotation;
	Color;
	Alpha;
	BlendAdd;
	Trans2x2;
}

typedef TilesheetInfo = {
	// nme tilesheet class
	var tilesheet:Tilesheet;
	// the tilesheet image
	var bitmap:BitmapData;
	// the number of tiles in this tilesheet
	var numTiles:Int;

	// holds the data passed to drawTiles
	var renderData:Array<Float>;
	var renderFlags:EnumFlags<RenderFlags>;
};

typedef SpriteInfo = {
	// which tilesheet this sprite starts on
	var index:Int;
	// the tile offset on the tilesheet
	var offset:Int;
}

class SpriteBatch
{

	public function new()
	{
		tilesheets = new Array<TilesheetInfo>();
		loadedSprites = new Hash<SpriteInfo>();
		dest = new Point();
		source = new Rectangle();
	}

	public function addImage(bitmap:String, ?origin:Point):SpriteInfo
	{
		if (loadedSprites.exists(bitmap))
		{
			// we've already loaded this bitmap
			return loadedSprites.get(bitmap);
		}
		var data:BitmapData = HXP.getBitmap(bitmap);
		if (data == null)
		{
			return null;
		}

		source.x = source.y = 0;
		source.width = data.width;
		source.height = data.height;

		var index = getTilesheet(source.width, source.height);
		var info = tilesheets[index];

		var spriteInfo = {
			index: index,
			offset: info.numTiles
		};

		drawToTilesheet(info, data, origin);

		loadedSprites.set(bitmap, spriteInfo);
		return spriteInfo;
	}

	public function addSpriteSheet(bitmap:String, tileWidth:Int, tileHeight:Int, ?origin:Point):SpriteInfo
	{
		if (loadedSprites.exists(bitmap))
		{
			// we've already loaded this bitmap
			return loadedSprites.get(bitmap);
		}
		var data:BitmapData = HXP.getBitmap(bitmap);
		if (data == null)
		{
			return null;
		}
		// tile width/height
		var columns = Std.int(data.width / tileWidth);
		var rows = Std.int(data.height / tileHeight);
		source.width = tileWidth;
		source.height = tileHeight;

		var index = getTilesheet(source.width, source.height);
		var info = tilesheets[index];
		var spriteInfo = {
			index: index,
			offset: info.numTiles
		};

		for (y in 0...rows)
		{
			for (x in 0...columns)
			{
				// calculate x/y per tile to keep index order
				source.x = x * tileWidth;
				source.y = y * tileHeight;
				info = drawToTilesheet(info, data, origin);
			}
		}

		loadedSprites.set(bitmap, spriteInfo);
		return spriteInfo;
	}

	public function addTilesheet(bitmap:String, frames:Array<Rectangle>, ?origin:Point):SpriteInfo
	{
		if (loadedSprites.exists(bitmap))
		{
			// we've already loaded this bitmap
			return loadedSprites.get(bitmap);
		}
		var data:BitmapData = HXP.getBitmap(bitmap);
		if (data == null)
		{
			return null;
		}

		var ts:Tilesheet = new Tilesheet(data);
		var info:TilesheetInfo = {
			tilesheet: ts,
			bitmap: null,
			numTiles: 0,
			renderData: new Array<Float>(),
			renderFlags: EnumFlags.ofInt(Tilesheet.TILE_ALPHA)
		};
		tilesheets.push(info);

		for (frame in frames)
		{
			ts.addTileRect(frame, origin);
		}
		loadedSprites.set(bitmap, null);
		return null;
	}

	public function draw(index:Int, x:Float, y:Float, frame:Int,
		scale:Float=1, alpha:Float=1, angle:Float=0, r:Float=1, g:Float=1, b:Float=1)
	{
		// find the tilesheet
		var ts = tilesheets[index];
		while (frame - ts.numTiles > 0)
		{
			frame = frame - ts.numTiles;
			index += 1;
			// make sure we don't go over the number of tilesheets
			if (index >= tilesheets.length)
			{
				return;
			}
			ts = tilesheets[index];
		}

		// apparently using an index is faster than pushing...
		var idx = ts.renderData.length;

		// push the data
		ts.renderData[idx++] = x;
		ts.renderData[idx++] = y;
		ts.renderData[idx++] = frame;
		if (ts.renderFlags.has(Scale))
		{
			ts.renderData[idx++] = scale;
		}
		if (ts.renderFlags.has(Rotation))
		{
			ts.renderData[idx++] = angle;
		}
		if (ts.renderFlags.has(Color))
		{
			ts.renderData[idx++] = r;
			ts.renderData[idx++] = g;
			ts.renderData[idx++] = b;
		}
		if (ts.renderFlags.has(Alpha))
		{
			ts.renderData[idx++] = alpha;
		}

		// if we're over the batch limit, draw it out
		if (ts.renderData.length > batchSize)
		{
			// draw and wipe out render data
			ts.tilesheet.drawTiles(HXP.tilesheet.graphics, ts.renderData, HXP.screen.smoothing, ts.renderFlags.toInt());
			HXP.clear(ts.renderData);
		}
	}

	/**
	 * Renders tilesheets to a graphics context
	 * @param graphics the context to render on
	 */
	public function render(graphics:Graphics, antialias:Bool=false)
	{
		for (ts in tilesheets)
		{
			// do we have anything to render for this tilesheet?
			if (ts.renderData.length > 0)
			{
				// draw and wipe out render data
				ts.tilesheet.drawTiles(graphics, ts.renderData, antialias, ts.renderFlags.toInt());
				HXP.clear(ts.renderData);
			}
		}
	}

	private inline function drawToTilesheet(info:TilesheetInfo, data:BitmapData, ?origin:Point):TilesheetInfo
	{
		if (dest.x + source.width > maxSheetWidth)
		{
			dest.x = 0;
			dest.y += lineHeight;
			lineHeight = Std.int(source.height);
			if (dest.y + source.height > maxSheetHeight)
			{
				info = createNewTilesheet();
			}
		}

		// copy image to tilesheet
		info.bitmap.copyPixels(data, source, dest);

		// see if we need to increase the current line height
		if (source.height > lineHeight)
		{
			lineHeight = Std.int(source.height);
		}

		// set source rectangle to new destination
		source.x = dest.x;
		source.y = dest.y;
		info.tilesheet.addTileRect(source, origin);

		// increase the number of tiles
		info.numTiles += 1;

		// move to next field
		dest.x += source.width;

		return info;
	}

	private function getTilesheet(width:Float, height:Float):Int
	{
		var index = 0, info:TilesheetInfo = null;

		// check if we already have tilesets
		if (tilesheets.length > 0)
		{
			// load up the latest tileset
			index = tilesheets.length - 1;
			info = tilesheets[index];
			// check if this is a external tilesheet
			if (info.bitmap == null)
			{
				info = createNewTilesheet();
				return tilesheets.length - 1;
			}
			// check if first sprite goes past sheet width
			if (dest.x + width > maxSheetWidth)
			{
				dest.x = 0;
				dest.y += lineHeight;
				lineHeight = 0;
			}
			// check if tile fits on current sheet
			if (dest.y + height > maxSheetHeight)
			{
				info = createNewTilesheet();
				return tilesheets.length - 1;
			}
		}
		else
		{
			info = createNewTilesheet();
			return tilesheets.length - 1;
		}

		return index;
	}

	private function createNewTilesheet(flags:Int = Tilesheet.TILE_ALPHA | Tilesheet.TILE_RGB):TilesheetInfo
	{
		var bd = HXP.createBitmap(maxSheetWidth, maxSheetHeight, true);

#if false
		// show tileset bitmaps on screen
		var b = new flash.display.Bitmap(bd);
		HXP.stage.addChild(b);
		b.x = tilesheets.length * maxSheetWidth;
#end

		var ts:Tilesheet = new Tilesheet(bd);
		var info = {
			tilesheet: ts,
			bitmap: bd,
			numTiles: 0,
			renderData: new Array<Float>(),
			renderFlags: EnumFlags.ofInt(flags)
		};
		tilesheets.push(info);
		dest.x = dest.y = 0; // reset position
		lineHeight = 0;
		return info;
	}

	private var source:Rectangle;
	private var dest:Point;
	private var lineHeight:Int;

	private var loadedSprites:Hash<SpriteInfo>;
	private var tilesheets:Array<TilesheetInfo>;

	private static inline var maxSheetWidth:Int = 1024;
	private static inline var maxSheetHeight:Int = 1024;
	private static inline var batchSize:Int = 140;
}

#end