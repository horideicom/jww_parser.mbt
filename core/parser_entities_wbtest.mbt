///|
/// CDataSolid の円弧/円ソリッド判定とフィールド対応を確認
test "parse arc solid to ArcSolid" {
  let writer = Writer::new()
  writer.write_dword(d=0U)
  writer.write_byte(b=(101).to_byte())
  writer.write_word(w=(10).to_uint16())
  writer.write_word(w=(1).to_uint16())
  writer.write_word(w=(2).to_uint16())
  writer.write_word(w=(3).to_uint16())
  writer.write_word(w=(4).to_uint16())
  writer.write_double(d=1.25)
  writer.write_double(d=2.5)
  writer.write_double(d=3.75)
  writer.write_double(d=0.8)
  writer.write_double(d=0.5)
  writer.write_double(d=1.0)
  writer.write_double(d=-1.25)
  writer.write_double(d=5.0)
  writer.write_dword(d=0x11223344U)
  let reader = Reader::new(data=writer.to_bytes())
  let entity = parse_entity_by_class(
    class_name="CDataSolid",
    reader~,
    version=700U,
  )
  match entity {
    Some(Entity::ArcSolid(solid)) => {
      inspect(solid.center_x, content="1.25")
      inspect(solid.center_y, content="2.5")
      inspect(solid.radius, content="3.75")
      inspect(solid.flatness, content="0.8")
      inspect(solid.tilt_angle, content="0.5")
      inspect(solid.start_angle, content="1")
      inspect(solid.arc_angle, content="-1.25")
      inspect(solid.solid_param, content="5")
      inspect(solid.color, content="287454020")
    }
    _ => fail("expected ArcSolid")
  }
}
