import json
import pytest
from engine.python.basketball_engine.storage import ProjectStore
from engine.python.basketball_engine.service import EngineService
from engine.python.basketball_engine.protocol import ProtocolError


@pytest.fixture
def store(tmp_path):
    store = ProjectStore(tmp_path / 'project')
    store.initialize()
    store.create_project('p', 'merge test')
    source = tmp_path / 'video.mp4'
    source.write_bytes(b'video')
    store.link_video({'source_path': str(source), 'source_size_bytes': 5,
        'source_mtime_ns': source.stat().st_mtime_ns, 'duration_ms': 60000})
    return store


def candidate(identifier, event, *, score=.5):
    return {'id': identifier, 'event_time_ms': event, 'default_start_ms': max(0,event-4000),
        'default_end_ms': event+2000, 'score': score, 'detector_version': 'test'}


def test_five_second_boundary_union_and_undo_preserve_reviews(store):
    video = store.list_videos()[0]['id']
    store.replace_candidates(video, [candidate('a',10000),candidate('b',15000),candidate('c',20001)])
    store.review_candidate('a','goal',note='confirmed goal')
    store.review_candidate('b','pending',note='long rim bounce')
    result = store.merge_nearby_candidates(video)
    assert result['merged_count'] == 1
    rows = store.list_candidates(video)
    assert [row['id'] for row in rows] == ['a','c']
    assert (rows[0]['review_start_ms'],rows[0]['review_end_ms']) == (6000,17000)
    assert rows[0]['review_status'] == 'goal'
    assert store.statistics()['candidate_count'] == 2
    assert store.context()['videos'][0]['candidate_count'] == 2
    with store.connect() as connection:
        assert connection.execute('SELECT COUNT(*) FROM candidates').fetchone()[0] == 3
        assert connection.execute("SELECT note FROM candidate_reviews WHERE candidate_id='b'").fetchone()[0] == 'long rim bounce'
        operations = connection.execute("SELECT entity_type FROM learning_records WHERE entity_type LIKE 'candidate_merge_%'").fetchall()
        assert len(operations) == 2
    restored = store.merge_nearby_candidates(video,undo=True)
    assert restored['restored_count'] == 1
    assert len(store.list_candidates(video)) == 3
    assert store.list_candidates(video)[0]['review_end_ms'] == 12000


def test_no_transitive_merges_even_when_merge_is_clicked_again(store):
    video = store.list_videos()[0]['id']
    store.replace_candidates(video,[candidate('a',10000),candidate('b',14000,score=.9),candidate('c',18000)])
    store.merge_nearby_candidates(video)
    assert len(store.list_candidates(video)) == 2
    assert store.merge_nearby_candidates(video)['merged_count'] == 0
    assert [row['event_time_ms'] for row in store.list_candidates(video)] == [14000,18000]


def test_overlap_beyond_five_seconds_is_not_merged_and_source_videos_stay_separate(store):
    video = store.list_videos()[0]['id']
    rows=[candidate('a',10000),candidate('b',16000)]
    store.replace_candidates(video,rows)
    store.update_clip_range('a', 6000, 25000)
    assert store.merge_nearby_candidates(video)['merged_count'] == 0


def test_nearby_candidates_are_merged_only_if_clip_ranges_overlap(store):
    video = store.list_videos()[0]['id']
    store.replace_candidates(video, [candidate('a', 10000), candidate('b', 13000)])
    store.update_clip_range('a', 6000, 10000)
    store.update_clip_range('b', 10000, 15000)
    assert store.merge_nearby_candidates(video)['merged_count'] == 0
    store.update_clip_range('b', 9999, 15000)
    assert store.merge_nearby_candidates(video)['merged_count'] == 1
    row = store.list_candidates(video)[0]
    assert (row['review_start_ms'], row['review_end_ms']) == (6000, 15000)
    store.update_clip_range(row['id'], 5000, 16000)
    assert store.merge_nearby_candidates(video, undo=True)['restored_count'] == 1
    assert len(store.list_candidates(video)) == 2
    edited = next(item for item in store.list_candidates(video) if item['id'] == row['id'])
    assert (edited['review_start_ms'], edited['review_end_ms']) == (5000, 16000)


def test_auto_excluded_duplicates_remain_reviewable_and_undoable(store):
    video = store.list_videos()[0]['id']
    rows = [candidate(f'auto{i}', 10000 + i * 300) for i in range(7)]
    store.replace_candidates(video, [*rows, candidate('kept', 10500)])
    for row in rows:
        store.review_candidate(row['id'], 'excluded', reason='auto_rim_check')
    store.review_candidate('kept', 'goal', note='human confirmation')
    assert store.merge_nearby_candidates(video)['merged_count'] == 6
    visible = store.list_candidates(video)
    assert len(visible) == 2
    excluded = next(row for row in visible if row['review_status'] == 'excluded')
    assert excluded['review_reason'] == 'auto_rim_check'
    assert (excluded['review_start_ms'], excluded['review_end_ms']) == (6000, 13800)
    assert next(row for row in visible if row['id'] == 'kept')['review_status'] == 'goal'
    assert store.merge_nearby_candidates(video, undo=True)['restored_count'] == 6
    assert len(store.list_candidates(video)) == 8


def test_analysis_does_not_merge_adjacent_nonoverlapping_clips(store):
    video = store.list_videos()[0]['id']
    first, second = candidate('a', 10000), candidate('b', 13000)
    first.update(default_start_ms=6000, default_end_ms=10000)
    second.update(default_start_ms=10000, default_end_ms=15000)
    store.replace_candidates(video, [first, second], merge_close=True)
    assert len(store.list_candidates(video)) == 2


def test_new_analysis_groups_atomically_and_undo_keeps_later_range_edits(store):
    video = store.list_videos()[0]['id']
    store.replace_candidates(video,[candidate('a',10000),candidate('b',13000)],merge_close=True)
    rows=store.list_candidates(video)
    assert len(rows)==1
    winner=rows[0]['id']
    store.update_clip_range(winner,1000,25000)
    store.merge_nearby_candidates(video,undo=True)
    assert len(store.list_candidates(video))==2
    assert next(row for row in store.list_candidates(video) if row['id']==winner)['review_end_ms']==25000
    store.merge_nearby_candidates(video)
    before=store.list_candidates(video)
    def fail():
        raise RuntimeError('cancel')
    with pytest.raises(RuntimeError):
        store.replace_candidates(video,[candidate('new',30000)],merge_close=True,before_commit=fail)
    assert store.list_candidates(video)==before


def test_protocol_busy_and_reopen(store):
    video=store.list_videos()[0]['id']
    store.replace_candidates(video,[candidate('a',10000),candidate('b',13000)])
    service=EngineService()
    payload={'project_root':str(store.root),'video_id':video}
    assert service.handle('merge_nearby_candidates',payload)['merged_count']==1
    assert len(ProjectStore(store.root).list_candidates(video))==1
    assert service.handle('undo_candidate_merge',payload)['restored_count']==1
    store.create_job('p',video,'analysis')
    with pytest.raises(ProtocolError,match='请等待当前任务结束后再合并'):
        service.handle('merge_nearby_candidates',payload)


def test_same_times_in_different_rois_and_videos_stay_independent(store):
    video=store.list_videos()[0]['id']
    roi1=store.save_roi(video,{'x1':0,'y1':0,'x2':200,'y2':200})
    roi2=store.save_roi(video,{'x1':100,'y1':0,'x2':300,'y2':200})
    a,b=candidate('a',10000),candidate('b',11000)
    a['roi_id'],b['roi_id']=roi1['id'],roi2['id']
    store.replace_candidates(video,[a,b])
    other=store.link_video({'source_path':str(store.root/'other.mp4'),'source_size_bytes':1,'source_mtime_ns':1,'duration_ms':60000})
    store.replace_candidates(other['id'],[candidate('c',10000)])
    assert store.merge_nearby_candidates(video)['merged_count']==0
    assert len(store.list_candidates())==3
